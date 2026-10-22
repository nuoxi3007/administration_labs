
DROP TRIGGER IF EXISTS trig_exhibition_control ON Exhibition_Participations;
DROP FUNCTION IF EXISTS exhibition_control();


CREATE OR REPLACE FUNCTION exhibition_control()
RETURNS TRIGGER AS $$
DECLARE
    painting_count INT;
    artist_id INT;
    start_date DATE;
    end_date DATE;
BEGIN
    RAISE NOTICE 'Операция: %, Картина ID=%', TG_OP, NEW.ID_Painting;

    -- Получаем художника
    SELECT ID_Artist INTO artist_id
    FROM Paintings
    WHERE ID_Painting = NEW.ID_Painting;

    IF artist_id IS NULL THEN
        RAISE EXCEPTION 'Картина с ID=% не найдена!', NEW.ID_Painting;
    END IF;

    -- Получаем даты выставки
    SELECT Start_Date, End_Date
    INTO start_date, end_date
    FROM Exhibitions
    WHERE ID_Exhibition = NEW.ID_Exhibition;

    IF start_date IS NULL THEN
        RAISE EXCEPTION 'Выставка не найдена!';
    END IF;

    -- Проверка 1: дата отправки должна быть в периоде выставки
    IF NEW.Send_Date < start_date OR NEW.Send_Date > end_date THEN
        RAISE EXCEPTION 
        'Дата отправки (%) вне периода выставки (% - %)',
        NEW.Send_Date, start_date, end_date;
    END IF;

    -- Проверка 2: возврат не раньше отправки
    IF NEW.Return_Date IS NOT NULL 
       AND NEW.Return_Date < NEW.Send_Date THEN
        RAISE EXCEPTION 
        'Дата возврата (%) раньше даты отправки (%)',
        NEW.Return_Date, NEW.Send_Date;
    END IF;

    -- Проверка 3: максимум 5 картин одного художника
    SELECT COUNT(*) INTO painting_count
    FROM Exhibition_Participations ep
    JOIN Paintings p ON ep.ID_Painting = p.ID_Painting
    WHERE ep.ID_Exhibition = NEW.ID_Exhibition
      AND p.ID_Artist = artist_id
      AND (TG_OP = 'INSERT' OR ep.ID_Painting <> OLD.ID_Painting);

    IF painting_count >= 5 THEN
        RAISE EXCEPTION 
        'На выставке уже 5 картин художника (ID=%)!',
        artist_id;
    END IF;

    -- Проверка 4: одна картина только на одной выставке
    IF EXISTS (
        SELECT 1
        FROM Exhibition_Participations
        WHERE ID_Painting = NEW.ID_Painting
        AND (TG_OP = 'INSERT' OR ID_Exhibition <> OLD.ID_Exhibition)
    ) THEN
        RAISE EXCEPTION 
        'Картина (ID=%) уже участвует в другой выставке!',
        NEW.ID_Painting;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. СОЗДАНИЕ ТРИГГЕРА


CREATE TRIGGER trig_exhibition_control
BEFORE INSERT OR UPDATE
ON Exhibition_Participations
FOR EACH ROW
EXECUTE FUNCTION exhibition_control();

--Тесты

DELETE FROM Exhibition_Participations;
DELETE FROM Exhibitions;
DELETE FROM Paintings WHERE Title LIKE 'Тест%';
DELETE FROM Artists WHERE Last_Name IN ('Тестов', 'Ван Гог');
DELETE FROM Paintings WHERE Title = 'Звёздная ночь';

-- Создаем выставку
INSERT INTO Exhibitions (Exhibition_Name, Start_Date, End_Date, Contact_Info)
VALUES ('Тестовая выставка', '2026-01-01', '2026-12-31', 'test@museum.ru');

-- Создаем художника Тестова
INSERT INTO Artists (Last_Name, First_Name, Birth_Year)
VALUES ('Тестов', 'Художник', 1980);

-- Получаем ID художника
DO $$
DECLARE
    v_artist_id INT;
BEGIN
    SELECT ID_Artist INTO v_artist_id FROM Artists WHERE Last_Name='Тестов';

    FOR i IN 1..6 LOOP
        INSERT INTO Paintings (Title, Creation_Year, ID_Artist)
        VALUES ('Тестовая картина ' || i, 2020 + i, v_artist_id);
    END LOOP;
END $$;

-- Создаем Ван Гога
INSERT INTO Artists (Last_Name, First_Name, Birth_Year)
VALUES ('Ван Гог', 'Винсент', 1853);

INSERT INTO Paintings (Title, Creation_Year, ID_Artist)
SELECT 'Звёздная ночь', 1889, ID_Artist
FROM Artists WHERE Last_Name='Ван Гог';


-- 5. ТЕСТИРОВАНИЕ


DO $$
DECLARE
    v_exh INT;
    v_paint INT;
BEGIN
    SELECT ID_Exhibition INTO v_exh 
    FROM Exhibitions 
    WHERE Exhibition_Name='Тестовая выставка';

    -- Добавляем 5 картин (должно пройти)
    FOR v_paint IN 
        SELECT ID_Painting 
        FROM Paintings 
        WHERE Title LIKE 'Тестовая картина%' 
        ORDER BY ID_Painting 
        LIMIT 5
    LOOP
        INSERT INTO Exhibition_Participations
        VALUES (v_paint, '2026-02-01', NULL, v_exh);
    END LOOP;

    -- Попытка добавить 6-ю картину
    BEGIN
        SELECT ID_Painting INTO v_paint 
        FROM Paintings 
        WHERE Title='Тестовая картина 6';

        INSERT INTO Exhibition_Participations
        VALUES (v_paint, '2026-02-01', NULL, v_exh);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Ожидаемая ошибка: %', SQLERRM;
    END;

    -- Добавляем картину Ван Гога
    SELECT ID_Painting INTO v_paint 
    FROM Paintings 
    WHERE Title='Звёздная ночь';

    INSERT INTO Exhibition_Participations
    VALUES (v_paint, '2026-03-01', NULL, v_exh);

    --  Возврат раньше отправки
    BEGIN
        INSERT INTO Exhibition_Participations
        VALUES (v_paint, '2026-04-01', '2026-03-01', v_exh);
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Ожидаемая ошибка: %', SQLERRM;
    END;

END $$;


-- 6 ИТОГОВЫЙ ВЫВОД

SELECT 
    p.Title AS "Картина",
    a.Last_Name AS "Художник",
    e.Exhibition_Name AS "Выставка"
FROM Exhibition_Participations ep
JOIN Paintings p ON ep.ID_Painting = p.ID_Painting
JOIN Artists a ON p.ID_Artist = a.ID_Artist
JOIN Exhibitions e ON ep.ID_Exhibition = e.ID_Exhibition
ORDER BY p.Title;
