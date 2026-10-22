
-- Лабораторная работа 2 — Многоверсионность и уровни изоляции транзакций PostgreSQL


--ОКНО 1 (СЕССИЯ 1) — Чтение (READ COMMITTED)

-- УРОВЕНЬ ИЗОЛЯЦИИ READ COMMITTED (по умолчанию)
SELECT*
FROM paintings 
WHERE Title = 'Мона Лиза';


-- Начальная проверка данных
BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT id_painting, title, creation_year, xmin, xmax
FROM paintings
WHERE title = 'Мона Лиза'
ORDER BY id_painting;


--ПЕРЕЙТИ В ОКНО 2, чтобы сделать первое обновление 
3097
-- Проверка многоверсионности (данные пока не изменились)
SELECT id_painting, title, creation_year, xmin, xmax
FROM paintings
WHERE title = 'Мона Лиза'
ORDER BY id_painting;



--ОКНО 2 (СЕССИЯ 2) — Первое изменение


BEGIN;



-- ОКНО 1 проверка

COMMIT;



--ОКНО 1 — После COMMIT


SELECT id_painting, title, creation_year, xmin, xmax
FROM paintings
WHERE title = 'Мона Лиза'
ORDER BY id_painting;

ROLLBACK;



--ОКНО 2 — Второе изменение (READ COMMITTED → 1506)


BEGIN;

UPDATE paintings
SET creation_year = 1506
WHERE title = 'Мона Лиза';

COMMIT;


--ОКНО 1 — REPEATABLE READ (создаём снимок)


BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

SELECT id_painting, title, creation_year, xmin, xmax
FROM paintings
WHERE title = 'Мона Лиза'
ORDER BY id_painting;

-- ОКНО 2, чтобы изменить данные 

-- Проверка: данные НЕ изменились внутри транзакции REPEATABLE READ
SELECT id_painting, title, creation_year, xmin, xmax
FROM paintings
WHERE title = 'Мона Лиза'
ORDER BY id_painting;

ROLLBACK;



--ОКНО 2 — Изменение для REPEATABLE READ


BEGIN;

UPDATE paintings
SET creation_year = 1510
WHERE title = 'Мона Лиза';

COMMIT;



--ОКНО 3 — Проверка актуальных данных


SELECT id_painting, title, creation_year, xmin, xmax
FROM paintings
WHERE title = 'Мона Лиза'
ORDER BY id_painting;


--ОКНО 1 — Новая транзакция REPEATABLE READ


BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Данные теперь видят новую версию
SELECT id_painting, title, creation_year, xmin, xmax
FROM paintings
WHERE title = 'Мона Лиза'
ORDER BY id_painting;

ROLLBACK;




xmin — номер транзакции, создавшей версию строки.  
xmax — номер транзакции, завершившей актуальность строки (0, если актуальна).  

READ COMMITTED — SELECT видит только зафиксированные данные.  
REPEATABLE READ — транзакция видит снимок данных на момент начала, даже если другие транзакции изменили данные.  

UPDATE создаёт новую версию строки, старая помечается через xmax.  


