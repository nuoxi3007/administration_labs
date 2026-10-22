






-- 1. ЛОГИЧЕСКОЕ КОПИРОВАНИЕ БАЗЫ (pg_dump)


set PATH=C:\Program Files\PostgreSQL\16\bin;%PATH%

pg_dump -U postgres -Fc -d museum -f C:\pg_backup\museum_backup.dump

DROP SCHEMA public CASCADE;

CREATE SCHEMA public AUTHORIZATION postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;

pg_restore -U postgres -d museum C:\pg_backup\museum_backup.dump


-- 2. ЛОГИЧЕСКОЕ КОПИРОВАНИЕ КЛАСТЕРА (pg_dumpall)



pg_dumpall -U postgres -f C:\pg_backup\full_cluster_backup.sql


DROP DATABASE museum;


SELECT datname FROM pg_database WHERE datname = 'museum';

-- Восстанавливаем весь кластер из бэкапа
psql -U postgres -f C:\pg_backup\full_cluster_backup.sql





-- ЧАСТЬ 3: Физическое копирование (pg_basebackup)
-- Копирование файлов базы данных
--Здесь мы копируем сами файлы с жесткого диска. Это самый надежный, но жесткий способ.
-- Создаём физическую копию файлов
pg_basebackup -U postgres -D C:\pg_backup\physical_museum -Fp -Xs

-- Теперь удалим базу (имитация аварии)
DROP DATABASE museum;


-- Win + R   services.msc 

-- Переименовываем старую папку data
cd C:\Program Files\PostgreSQL\16 rename data data_old

-- Создаём пустую папку data
mkdir data


icacls "C:\Program Files\PostgreSQL\16\data" /grant "NT AUTHORITY\NETWORK SERVICE":(F) /T


