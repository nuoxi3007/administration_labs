
-- ЧАСТЬ 1. АУДИТ ТАБЛИЦЫ PAINTINGS (Картины)


-- 1.1 Создаем таблицу для хранения логов аудита картин
CREATE TABLE paintings_audit (
    audit_id SERIAL PRIMARY KEY,
    performed_on TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    performed_by TEXT NOT NULL DEFAULT CURRENT_USER,
    operation TEXT NOT NULL,
    old_data JSONB,
    new_data JSONB
);

-- 1.2 Создаем функцию-триггер для аудита картин
CREATE OR REPLACE FUNCTION audit_paintings_func()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO paintings_audit (performed_on, performed_by, operation, new_data)
        VALUES (CURRENT_TIMESTAMP, CURRENT_USER, 'INSERT', to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO paintings_audit (performed_on, performed_by, operation, old_data, new_data)
        VALUES (CURRENT_TIMESTAMP, CURRENT_USER, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO paintings_audit (performed_on, performed_by, operation, old_data)
        VALUES (CURRENT_TIMESTAMP, CURRENT_USER, 'DELETE', to_jsonb(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 1.3 Создаем триггер на таблицу Paintings
-- Примечание: PostgreSQL приводит имена без кавычек к нижнему регистру (paintings)
CREATE TRIGGER trg_audit_paintings
AFTER INSERT OR UPDATE OR DELETE ON paintings
FOR EACH ROW
EXECUTE FUNCTION audit_paintings_func();



-- ЧАСТЬ 2. АУДИТ ТАБЛИЦЫ RESTORATIONS (Реставрации)


-- 2.1 Создаем таблицу для хранения логов аудита реставраций
CREATE TABLE restorations_audit (
    audit_id SERIAL PRIMARY KEY,
    performed_on TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    performed_by TEXT NOT NULL DEFAULT CURRENT_USER,
    operation TEXT NOT NULL,
    old_data JSONB,
    new_data JSONB
);
-- 2.2 Создаем функцию-триггер для аудита реставраций
CREATE OR REPLACE FUNCTION audit_restorations_func()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO restorations_audit (performed_on, performed_by, operation, new_data)
        VALUES (CURRENT_TIMESTAMP, CURRENT_USER, 'INSERT', to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO restorations_audit (performed_on, performed_by, operation, old_data, new_data)
        VALUES (CURRENT_TIMESTAMP, CURRENT_USER, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO restorations_audit (performed_on, performed_by, operation, old_data)
        VALUES (CURRENT_TIMESTAMP, CURRENT_USER, 'DELETE', to_jsonb(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 2.3 Создаем триггер на таблицу Restorations
CREATE TRIGGER trg_audit_restorations
AFTER INSERT OR UPDATE OR DELETE ON restorations
FOR EACH ROW
EXECUTE FUNCTION audit_restorations_func();



-- ЧАСТЬ 3. ТЕСТИРОВАНИЕ АУДИТА


-- 3.1 Подготовительные данные (чтобы сработали внешние ключи)
-- Вставляем минимально необходимые записи для создания Картины и Реставрации

INSERT INTO artists (last_name, first_name, birth_year) 
VALUES ('Петров', 'Петр', 1980);

INSERT INTO styles (style_name) 
VALUES ('Рококо');

INSERT INTO Locations (Location_Name) VALUES ('Зал 1');


INSERT INTO owners (last_name, first_name, contact_info) 
VALUES ('Иванов', 'Иван', 'ivan@mail.ru');

INSERT INTO restorers (last_name, first_name, contact_info) 
VALUES ('Сидоров', 'Сидр', 'sidorov@rest.ru');

-- 3.2 Тестирование аудита таблицы Paintings

-- INSERT: Добавляем картину
INSERT INTO paintings (title, creation_year, id_artist, id_style, id_location, id_owner)
VALUES ('Иисус смотрит в даль', 2020, 1, 1, 1, 1);

-- UPDATE: Меняем название и год (триггер запишет старые и новые данные)
UPDATE paintings 
SET title = 'Вечер в лесу', creation_year = 2021 
WHERE title = 'Иисус смотрит в даль';

-- DELETE: Удаляем картину (триггер запишет удаленные данные)
DELETE FROM paintings WHERE title = 'Вечер в лесу';


-- 3.3 Тестирование аудита таблицы Restorations

-- Сначала создадим картину снова, чтобы было что реставрировать (для FK)
INSERT INTO paintings (title, creation_year, id_artist, id_style, id_location, id_owner)
VALUES ('Натюрморт', 2022, 1, 1, 1, 1);
-- Получим ID этой картины (в реальном сценарии мы бы знали ID, здесь возьмем последний)
-- Для простоты теста предположим, что ID картины = 1 (или используйте подзапрос)
-- Вставим реставрацию для ID_Painting = 1 (проверьте актуальный ID через SELECT * FROM paintings)

INSERT INTO restorations (restoration_start_date, id_restorer, id_painting)
VALUES ('2023-01-01', 1, 1);

-- UPDATE: Меняем дату окончания реставрации
UPDATE restorations 
SET restoration_end_date = '2023-02-01' 
WHERE id_restoration = 1;

-- DELETE: Отменяем запись о реставрации
DELETE FROM restorations WHERE id_restoration = 1;


-- ЧАСТЬ 4. ПРОВЕРКА РЕЗУЛЬТАТОВ (ПРОСМОТР ЖУРНАЛОВ)


-- Просмотр аудита изменений Картин
SELECT * FROM paintings_audit ORDER BY audit_id;

-- Просмотр аудита изменений Реставраций
SELECT * FROM restorations_audit ORDER BY audit_id;

-- Анализ: можно увидеть, кто (performed_by), когда (performed_on) и что (operation) сделал,
-- а также какие данные были до (old_data) и после (new_data).



-- ЧАСТЬ 5. ОЧИСТКА 

-- Если нужно удалить аудит и начать заново:
DROP TRIGGER IF EXISTS trg_audit_paintings ON paintings;
DROP TRIGGER IF EXISTS trg_audit_restorations ON restorations;
 DROP FUNCTION IF EXISTS audit_paintings_func();
DROP FUNCTION IF EXISTS audit_restorations_func();
DROP TABLE IF EXISTS paintings_audit;
DROP TABLE IF EXISTS restorations_audit;