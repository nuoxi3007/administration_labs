REVOKE ALL PRIVILEGES ON DATABASE museum FROM admin_system, restorer, director, artist, digital_staff, curator_group, gabriel, billy, alex, will, max CASCADE;
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM admin_system, restorer, director, artist, digital_staff, curator_group, gabriel, billy, alex, will, max CASCADE;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM admin_system, restorer, director, artist, digital_staff, curator_group, gabriel, billy, alex, will, max CASCADE;

DROP ROLE IF EXISTS admin_system, restorer, director, artist, digital_staff, curator_group, gabriel, billy, alex, will, max;

CREATE ROLE admin_system LOGIN PASSWORD 'admin1';
CREATE ROLE restorer LOGIN PASSWORD 'restorer1';
CREATE ROLE director LOGIN PASSWORD 'director1';
CREATE ROLE artist LOGIN PASSWORD 'artist1';
CREATE ROLE digital_staff LOGIN PASSWORD 'digital1';
CREATE ROLE curator_group NOLOGIN;

CREATE ROLE gabriel  LOGIN PASSWORD 'gabriel123';
CREATE ROLE billy  LOGIN PASSWORD 'billy123';
CREATE ROLE alex LOGIN PASSWORD 'alex123';
CREATE ROLE will LOGIN PASSWORD 'will123';
CREATE ROLE max LOGIN PASSWORD 'max123';

GRANT ALL PRIVILEGES ON DATABASE museum TO admin_system;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO admin_system;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO admin_system;


GRANT SELECT ON Artists, Paintings, Locations, Restorers TO restorer;
GRANT SELECT, INSERT, UPDATE ON Restorations TO restorer;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO director;
GRANT INSERT, UPDATE, DELETE ON Artists, Paintings, Exhibitions TO director;
GRANT INSERT, UPDATE ON Exhibition_Participations TO director;

GRANT SELECT ON Artists, Styles, Exhibitions TO artist;
GRANT SELECT, INSERT, UPDATE ON Paintings TO artist;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO digital_staff;

--групповая роль
GRANT SELECT, INSERT, UPDATE ON Exhibitions, Exhibition_Participations TO curator_group;
GRANT SELECT ON Paintings, Artists TO curator_group;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO curator_group;

-- добавление в групповую роль
GRANT curator_group TO director, restorer, will;      
GRANT digital_staff TO billy, alex;                   
GRANT artist TO gabriel;                                 
GRANT restorer TO max; 

-- используем WITH GRANT OPTION;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO artist, director, restorer;
GRANT SELECT, INSERT ON Paintings, Exhibitions TO director WITH GRANT OPTION;

--тесты
ALTER ROLE artist WITH PASSWORD 'artist2025';

INSERT INTO Paintings (Title, Creation_Year, Century) VALUES ('тест вставки6', 2024, 21);
REVOKE INSERT ON Paintings FROM artist;

INSERT INTO Paintings (Title, Creation_Year, Century) VALUES ('тест3  ', 2024, 21);

-- для WITH GRANT OPTION;
\c museum director
GRANT SELECT ON Paintings TO will;

\c museum postgres
SET ROLE artist;
INSERT INTO Paintings (Title, Creation_Year, Century) VALUES ('Тест через SET ROLE2 ', 2024, 21); 
SELECT * FROM Paintings LIMIT 2;
RESET ROLE;

\c museum director
SET ROLE will;
RESET ROLE;


\c museum director
SET ROLE curator_group;

INSERT INTO Exhibitions (Exhibition_Name, Start_Date, Contact_Info) VALUES ('Выставка Уилла3', '2024-12-01', 'контакты');
SELECT * FROM Paintings;
RESET ROLE;

\c museum billy
SET ROLE restorer;


\dp Paintings
\dp Exhibitions