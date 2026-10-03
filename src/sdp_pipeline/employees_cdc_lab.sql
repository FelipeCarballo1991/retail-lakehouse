--------------------------------------------------------------------
-- EMPLOYEES CDC LAB — ejercicio guiado con CSV (AUTO CDC INTO, SCD Type 1)
-- Parte del proyecto "Retail Lakehouse"
-- Fuente: ${source}/employees  (landing_zone/employees montada como Volume)
--------------------------------------------------------------------

CREATE OR REFRESH STREAMING TABLE bronze.employees_raw_bronze
  TBLPROPERTIES ("pipelines.reset.allowed" = false)
AS
SELECT *, current_timestamp() AS ingestion_time, _metadata.file_name AS source_file
FROM STREAM read_files("${source}/employees", format => 'CSV', header => true);

CREATE OR REFRESH STREAMING TABLE bronze.employees_bronze_clean
  (
    CONSTRAINT valid_emp_id EXPECT (EmployeeID IS NOT NULL) ON VIOLATION DROP ROW
  )
AS
SELECT EmployeeID, FirstName, upper(Country) AS Country, Department, Salary,
       HireDate, Operation, ProcessDate
FROM STREAM bronze.employees_raw_bronze;

CREATE OR REFRESH STREAMING TABLE silver.current_employees;

CREATE FLOW employees_scd1_flow AS
AUTO CDC INTO silver.current_employees
FROM STREAM bronze.employees_bronze_clean
KEYS (EmployeeID)
APPLY AS DELETE WHEN Operation = 'delete'
SEQUENCE BY ProcessDate
COLUMNS * EXCEPT (Operation)
STORED AS SCD TYPE 1;
