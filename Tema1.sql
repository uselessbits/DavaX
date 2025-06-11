CREATE TABLE employees(
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    firstname VARCHAR(30) NOT NULL,
    lastname VARCHAR(30) NOT NULL,
    email VARCHAR(30) UNIQUE
);

CREATE TABLE timesheets(
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    total_hours NUMBER(5,2),
    start_date DATE NOT NULL,
    project_name VARCHAR(30),
    employee_id INTEGER REFERENCES employees(id) ON DELETE CASCADE,
    status VARCHAR2(20) DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','SUBMITTED','APPROVED','REJECTED')),
    entries_json CLOB NOT NULL CHECK(entries_json is JSON),
    CHECK (total_hours >= 0 AND  total_hours <= 50)
    --index on start date, employee_id
);
--populam tabelele
INSERT INTO employees(firstname, lastname, email)
VALUES ('Alice', 'Anderson', 'alice.anderson@endava.com');

INSERT INTO employees (firstname, lastname, email)
VALUES ('Bob', 'Brown', 'bob.brown@endava.com');

--selectam angajati introdusi deja(toate coloanele)
SELECT * FROM employees;

DECLARE
  v_json CLOB := '
    {
      "days": [
        {"Day":"Monday",   "Hours":8,   "Project":"ACCT-101", "Desc":"Client meeting"},
        {"Day":"Tuesday",  "Hours":7.5, "Project":"ACCT-101", "Desc":"Report drafting"},
        {"Day":"Wednesday","Hours":8,   "Project":"DEV-202",  "Desc":"Coding module"},
        {"Day":"Thursday", "Hours":6,   "Project":"DEV-202",  "Desc":"Code review"},
        {"Day":"Friday",   "Hours":4,   "Project":"DEV-202",  "Desc":"Bug fixes"}
      ]
    }';
BEGIN
  INSERT INTO timesheets (
    start_date,
    project_name,
    employee_id,
    entries_json
  ) VALUES (
    DATE '2025-06-09',
    'Endava Portal',
    1,          -- Alice’s ID
    v_json
  );
  COMMIT;
END;
/

SELECT * FROM timesheets;


CREATE OR REPLACE TRIGGER triggeer_timesheets
BEFORE INSERT OR UPDATE ON timesheets
FOR EACH ROW
DECLARE
v_sum NUMBER;
BEGIN
  -- Sum Hours from the JSON array
  SELECT NVL(SUM(jt.Hours), 0)--daca e null, pune 0
    INTO v_sum
    FROM JSON_TABLE(
           :NEW.entries_json,
           '$.days[*]'
           COLUMNS (
             Hours NUMBER PATH '$.Hours'
           )
         ) jt;

  -- Populate total_hours
  :NEW.total_hours := v_sum;
  :NEW.status := NVL(:NEW.status, 'DRAFT');--daca e null, pune draft
END;
/

--creeam index pe start date
CREATE INDEX index_timesheets_date
ON timesheets(start_date);

--returns all timesheets in the past year
CREATE VIEW all_timesheets AS 
SELECT * FROM timesheets WHERE start_date BETWEEN (SYSDATE-INTERVAL '1' YEAR) AND SYSDATE;

SELECT * FROM all_timesheets;

--materialized view of all hours from all timesheets

CREATE MATERIALIZED VIEW total_hours AS
SELECT SUM(total_hours) FROM timesheets;


SELECT * FROM total_hours;

--numarul de timesheets al fiecarei persoane


SELECT E.id, E.firstname, E.lastname, COUNT(T.id) AS timesheet_count FROM employees E
LEFT JOIN timesheets T ON E.id = T.employee_id
GROUP BY E.id, E.firstname, E.lastname
ORDER BY E.id;


