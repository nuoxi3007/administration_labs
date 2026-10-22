

-- Обновление статистики для корректного плана запросов
ANALYZE artists;
ANALYZE paintings;
ANALYZE styles;
ANALYZE countries;

-- ЧАСТЬ 1. УДАЛЕНИЕ СУЩЕСТВУЮЩИХ ОБЪЕКТОВ (для повторного запуска)

DROP FUNCTION IF EXISTS get_artists_sorted();
DROP FUNCTION IF EXISTS get_style_statistics(VARCHAR);
DROP PROCEDURE IF EXISTS update_painting_centuries();
DROP ROLE IF EXISTS museum_test;

-- ЧАСТЬ 2. СОЗДАНИЕ ФУНКЦИЙ

-- 2.1. Функция с SECURITY INVOKER (выполняется с правами вызывающего)
CREATE OR REPLACE FUNCTION get_artists_sorted()
RETURNS TABLE (
    out_artist_id INTEGER,
    out_last_name VARCHAR,
    out_first_name VARCHAR
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id_artist,
        a.last_name,
        a.first_name
    FROM artists a
    ORDER BY a.last_name;
END;
$$ LANGUAGE plpgsql
SECURITY INVOKER;

-- 2.2. Функция с SECURITY DEFINER (выполняется с правами владельца)
CREATE OR REPLACE FUNCTION get_style_statistics(p_style_name VARCHAR)
RETURNS TABLE (
    out_max_year INTEGER,
    out_min_year INTEGER,
    out_avg_year NUMERIC
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        MAX(p.creation_year),
        MIN(p.creation_year),
        AVG(p.creation_year)::NUMERIC
    FROM paintings p
    JOIN styles s 
        ON p.id_style = s.id_style
    WHERE s.style_name = p_style_name;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;

-- ЧАСТЬ 3. СРАВНЕНИЕ ПРОИЗВОДИТЕЛЬНОСТИ


-- 3.1. Прямой запрос к таблице Artists
EXPLAIN ANALYZE
SELECT *
FROM artists
ORDER BY last_name;

-- 3.2. Вызов функции get_artists_sorted()
EXPLAIN ANALYZE
SELECT * FROM get_artists_sorted();

-- 3.3. Прямой запрос к таблицам Paintings + Styles
EXPLAIN ANALYZE
SELECT 
    MAX(p.creation_year) AS max_year,
    MIN(p.creation_year) AS min_year,
    AVG(p.creation_year) AS avg_year
FROM paintings p
JOIN styles s 
    ON p.id_style = s.id_style
WHERE s.style_name = 'Импрессионизм';

-- 3.4. Вызов функции get_style_statistics()
EXPLAIN ANALYZE
SELECT * FROM get_style_statistics('Импрессионизм');

-- ЧАСТЬ 4. ПРОВЕРКА ПРАВ ДОСТУПА (SECURITY INVOKER / DEFINER)


-- Создание тестового пользователя
CREATE ROLE museum_test LOGIN PASSWORD '123';

-- Отзыв прав на таблицы
REVOKE ALL ON artists FROM museum_test;
REVOKE ALL ON paintings FROM museum_test;
REVOKE ALL ON styles FROM museum_test;

-- Предоставление прав на выполнение функций
GRANT EXECUTE ON FUNCTION get_artists_sorted() TO museum_test;
GRANT EXECUTE ON FUNCTION get_style_statistics(VARCHAR) TO museum_test;


-- ЧАСТЬ 5. ХРАНИМАЯ ПРОЦЕДУРА


CREATE OR REPLACE PROCEDURE update_painting_centuries() AS $$
BEGIN
    UPDATE paintings
    SET century = CEIL(creation_year::NUMERIC / 100)
    WHERE creation_year IS NOT NULL 
      AND century IS NULL;
END;
$$ LANGUAGE plpgsql;

-- Вызов процедуры
CALL update_painting_centuries();

-- Проверка результата
SELECT id_painting, title, creation_year, century 
FROM paintings 
WHERE century IS NOT NULL 
LIMIT 5;

-- ============================================================================
-- ЧАСТЬ 6. ДОПОЛНИТЕЛЬНЫЙ ПРИМЕР (Функция в WHERE - не рекомендуется)
-- ============================================================================

-- Создаём функцию для демонстрации снижения производительности
CREATE OR REPLACE FUNCTION is_style_impressionism(p_style_id INT)
RETURNS BOOLEAN AS $$
DECLARE
    v_style_name VARCHAR;
BEGIN
    SELECT style_name INTO v_style_name FROM styles WHERE id_style = p_style_id;
    RETURN v_style_name = 'Импрессионизм';
END;
$$ LANGUAGE plpgsql SECURITY INVOKER;

-- Прямой запрос (быстрее)
EXPLAIN ANALYZE
SELECT COUNT(*) 
FROM paintings p
JOIN styles s ON p.id_style = s.id_style
WHERE s.style_name = 'Импрессионизм';

-- Запрос через функцию в WHERE (медленнее)
EXPLAIN ANALYZE
SELECT COUNT(*) 
FROM paintings p
WHERE is_style_impressionism(p.id_style);
