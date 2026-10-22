
 -- ЛАБОРАТОРНАЯ РАБОТА №3
 --  Тема: Конфликты блокировок и взаимоблокировки (Deadlock)

-- Проверяем наличие картин для эксперимента
SELECT ID_Painting, Title, Creation_Year 
FROM Paintings 
WHERE Title IN ('Мона Лиза', 'Звёздная ночь', 'Крик')
ORDER BY Title;


 --  2. КОНФЛИКТ БЛОКИРОВОК (LOCK CONFLICT)



--СЕССИЯ 1 (Окно 1)


BEGIN;

UPDATE Paintings 
SET Creation_Year = 1505 
WHERE Title = 'Мона Лиза';

-- Транзакцию не фиксируем (без COMMIT)
-- Строка заблокирована



--СЕССИЯ 2 (Окно 2)


BEGIN;

UPDATE Paintings 
SET Creation_Year = 1506 
WHERE Title = 'Мона Лиза';

-- Запрос будет ожидать освобождения блокировки


--СЕССИЯ 3 (Окно 3)


BEGIN;

UPDATE Paintings 
SET Creation_Year = 1507 
WHERE Title = 'Мона Лиза';

-- Также перейдет в состояние ожидания (Lock)


/* 3. АНАЛИЗ ОЧЕРЕДИ БЛОКИРОВОК
   Открыть 4-е окно терминала */
SELECT 
    pid,
    state,
    wait_event_type,
    wait_event,
    pg_blocking_pids(pid) as blocked_by,
    LEFT(query, 50) as short_query
FROM pg_stat_activity
WHERE backend_type = 'client backend'
  AND query NOT LIKE '%pg_stat_activity%';  -- исключаем сам запрос;


-- Расширенный анализ

SELECT 
    pid AS "ID процесса",
    usename AS "Пользователь",
    state AS "Состояние",
    wait_event_type AS "Тип ожидания",
    LEFT(query, 60) AS "Запрос",
    pg_blocking_pids(pid) AS "Блокируется процессами",
    age(now(), query_start) AS "Длительность"
FROM pg_stat_activity
WHERE backend_type = 'client backend'
  AND state <> 'idle'
  AND query LIKE '%UPDATE%Paintings%'
ORDER BY state DESC;


--4. РЕШЕНИЕ КОНФЛИКТА


-- Способ 1: корректное завершение транзакции (в Сессии 1)

COMMIT;


-- Способ 2: отмена ожидающего запроса

SELECT pid, query
FROM pg_stat_activity
WHERE wait_event_type = 'Lock'
  AND query LIKE '%Мона Лиза%'
LIMIT 1;

-- Отмена (заменить <PID> на найденный идентификатор)
-- SELECT pg_cancel_backend(<PID>);


-- Способ 3: завершение блокирующей сессии
-- Требуются права суперпользователя

-- SELECT pg_terminate_backend(b.pid)
-- FROM unnest(pg_blocking_pids(<PID_заблокированного>)) AS b(pid);

-- провекра картин 
SELECT Title, Creation_Year, xmin, xmax
FROM Paintings 
WHERE Title IN ('Мона Лиза', 'Звёздная ночь', 'Крик')
ORDER BY Title;
/* 5. ВЗАИМОБЛОКИРОВКА (DEADLOCK)
   Открыть 2 новых окна терминала */



 --СЕССИЯ A (Окно 5)


BEGIN;

UPDATE Paintings 
SET Creation_Year = 1505 
WHERE Title = 'Мона Лиза';



--  СЕССИЯ B (Окно 6)


BEGIN;

UPDATE Paintings 
SET Creation_Year = 1890 
WHERE Title = 'Звёздная ночь';



--Создание циклической зависимости


-- В Сессии A

UPDATE Paintings 
SET Creation_Year = 1891 
WHERE Title = 'Звёздная ночь';
-- Ожидание


-- В Сессии B

UPDATE Paintings 
SET Creation_Year = 1506 
WHERE Title = 'Мона Лиза';
-- ERROR: deadlock detected


-- 6. АНАЛИЗ ПОСЛЕ DEADLOCK


SELECT 
    pid,
    LEFT(query, 50) AS query,
    state,
    CASE 
        WHEN state = 'idle in transaction (aborted)' THEN 'Транзакция-жертва'
        WHEN state = 'idle in transaction' THEN 'Активная транзакция'
        ELSE state
    END AS status
FROM pg_stat_activity
WHERE query LIKE '%UPDATE%Paintings%';


-- Завершение транзакций
-- В сессии-жертве:
-- ROLLBACK;

-- В выжившей сессии:
-- COMMIT;




--8. АДМИНИСТРИРОВАНИЕ БЛОКИРОВОК


-- Все блокировки таблицы Paintings

SELECT locktype,
       relation::regclass,
       mode,
       granted,
       pid
FROM pg_locks
WHERE relation = 'paintings'::regclass;


-- Самые долгие ожидания

SELECT pid,
       now() - query_start AS duration,
       state,
       wait_event_type,
       LEFT(query, 60)
FROM pg_stat_activity
WHERE wait_event_type IS NOT NULL
ORDER BY duration DESC
LIMIT 5;


-- 9. ФИНАЛ
SELECT Title, Creation_Year, xmin, xmax
FROM Paintings
WHERE Title IN ('Мона Лиза', 'Звёздная ночь', 'Крик')
ORDER BY Title;


