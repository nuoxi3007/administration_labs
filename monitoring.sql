
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public';

DROP FUNCTION IF EXISTS public.count_paintings_by_artist(integer);
DROP FUNCTION IF EXISTS public.is_artist_active(integer);

-- 1. Создание функции, подсчитывающей картины художника 

CREATE OR REPLACE FUNCTION public.count_paintings_by_artist(p_artist_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    paint_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO paint_count
    FROM Paintings
    WHERE ID_Artist = p_artist_id;

    RETURN paint_count;
END;
$$;

-- Проверка таблицы
SELECT * FROM Paintings;

SELECT * FROM count_paintings_by_artist(1);


-- 2. Создание функции, определяющей, является ли художник современником (нет даты смерти)

CREATE OR REPLACE FUNCTION public.is_artist_active(p_artist_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM Artists
        WHERE ID_Artist = p_artist_id
          AND Death_Year IS NULL
    );
END;
$$;

--  Вызов функции
SELECT * FROM is_artist_active(1);


-------------------------------- ЧАСТЬ 1: СТАТИСТИКА pg_stat_...

-- путь к файлу конфигурации: C:\Program Files\PostgreSQL\16\data\postgresql.conf

-- выбираем параметры журнала (представление pg_settings — его настройки)
SELECT * FROM pg_settings 
WHERE name IN (
    'track_activities',             -- мониторинг текущих команд
    'track_counts',                 -- сбор статистики по таблицам и индексам
    'track_functions',              -- отслеживание исп-я пользовательских функций
    'track_io_timing',              -- мониторинг времени чтения и записи блоков
    'track_wal_io_timing'           -- мониторинг времени записи WAL
);

-- изменение отслеживания функций
ALTER SYSTEM SET track_functions = 'all'; 
SELECT pg_reload_conf();

-- для проверки параметра:
SHOW track_functions;

-- Вызови функции несколько раз, чтобы накопилась статистика
SELECT count_paintings_by_artist(1);
SELECT is_artist_active(1);

-- Просмотр статистики
SELECT * FROM pg_stat_user_functions WHERE funcname IN ('count_paintings_by_artist', 'is_artist_active');


---------------------------- ЧАСТЬ 2: ЖУРНАЛ СООБЩЕНИЙ (ЛОГИ)

-- путь к файлам журнала C:\Program Files\PostgreSQL\16\data\log\

-- выбираем параметры журнала
SELECT name, setting 
FROM pg_settings 
WHERE name IN (
    'log_destination',    			--куда выводим
    'logging_collector',  			--коллектор сообщений
    'log_directory',      			--директория логгирования
    'log_filename',       			--имя файла (дата+время)
    'log_rotation_age',   			--время ротации файлов в минутах
	'log_rotation_size',  			--размер файла для ротации в Кб
	'log_connections',    			--логгировать ли подключения к базе
	'log_statement',      			--логгировать ли запросы и какие		
	'log_min_messages',    			--уровень серьёзности логгируемых сообщений
	'log_min_duration_statement',	--минимальная длительность исполнения логгируемых запросов в миллисекундах
	'log_duration',					--логгировать ли длительность ВСЕХ запросов (только если предыдущий = -1/0)
	'log_checkpoints',				--контрольные точки
	'log_lock_waits',				--блокировки, время ожидания по к-м  deadlock_timeout
	'track_activities',				--
	'track_counts'					--
);
-- записываем в логи все запросы
ALTER SYSTEM SET log_statement = 'mod';
SELECT pg_reload_conf();

-- изменение уровня логгирования на INFO
ALTER SYSTEM SET log_min_messages = 'info';
SELECT pg_reload_conf();

-- логировать запросы медленнее 45 мс
ALTER SYSTEM SET log_min_duration_statement = 45; 
SELECT pg_reload_conf();

-- добавляем вывод в CSV формат
ALTER SYSTEM SET log_destination = 'stderr, csvlog';
SELECT pg_reload_conf();

-- ПРОВЕРКА: сгенерируй действие для лога
INSERT INTO Styles (Style_Name) VALUES ('Тестовый стиль');

-- Проверка параметров:
SHOW log_statement;

SHOW log_min_messages;

SHOW log_min_duration_statement;

SHOW log_destination;

SET log_min_duration_statement = 100;

SELECT pg_sleep(0.2);
--------------------------------------------- ЧАСТЬ 3: РАСШИРЕННАЯ СТАТИСТИКА (pg_stat_statements)

-- ШАГ 1: Подготовка сервера (Делается один раз)
-- Прописываем модуль в конфиг (ПОСЛЕ ЭТОГО НУЖНО ПЕРЕЗАПУСТИТЬ СЛУЖБУ В services.msc)
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';

-- ШАГ 2: Проверка загрузки библиотеки (Показываем преподу ПОСЛЕ перезапуска службы)
SHOW shared_preload_libraries;

-- ШАГ 3: Активация расширения в текущей базе данных
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Проверяем статус установки
SELECT name, installed_version FROM pg_available_extensions WHERE name = 'pg_stat_statements';

-- ШАГ 4: Обнуление статистики (Начинаем чистый эксперимент)
SELECT pg_stat_statements_reset();

-- ШАГ 5: Генерация нагрузки (Имитация работы пользователей с Художественной галереей)
SELECT * FROM Artists WHERE Birth_Year > 1800;
SELECT * FROM Paintings JOIN Styles ON Paintings.ID_Style = Styles.ID_Style;
SELECT pg_sleep(0.5); -- Искусственно долгий запрос (полсекунды) для наглядности

-- ШАГ 6: Анализ результатов
SELECT 
    query, 
    calls, 
    total_exec_time, 
    rows 
FROM pg_stat_statements 
WHERE query NOT LIKE '%pg_stat%' 
ORDER BY total_exec_time DESC 
LIMIT 5;

DROP EXTENSION IF EXISTS pg_stat_statements;