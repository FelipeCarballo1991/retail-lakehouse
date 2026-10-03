--------------------------------------------------------------------
-- CUSTOMERS CDC PIPELINE — Bronze -> Bronze Clean -> Silver (AUTO CDC INTO, SCD Type 1)
-- Parte del proyecto "Retail Lakehouse"
-- Fuente: ${source}/customers  (landing_zone/customers montada como Volume)
--------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------
-- BRONZE: ingesta cruda del feed CDC
----------------------------------------------------------------------------------------------------------------
CREATE OR REFRESH STREAMING TABLE bronze.customers_bronze_raw
  COMMENT "Datos crudos del feed CDC de clientes"
  TBLPROPERTIES ("quality" = "bronze")
AS
SELECT
  *,
  current_timestamp() AS processing_time,
  _metadata.file_name AS source_file
FROM STREAM read_files("${source}/customers", format => 'JSON');

----------------------------------------------------------------------------------------------------------------
-- BRONZE CLEAN: validaciones (toleran nulos SOLO cuando operation = 'DELETE')
----------------------------------------------------------------------------------------------------------------
CREATE OR REFRESH STREAMING TABLE bronze.customers_bronze_clean
  (
    CONSTRAINT valid_id EXPECT (customer_id IS NOT NULL) ON VIOLATION FAIL UPDATE,
    CONSTRAINT valid_operation EXPECT (operation IS NOT NULL) ON VIOLATION DROP ROW,
    CONSTRAINT valid_name EXPECT (name IS NOT NULL OR operation = "DELETE"),
    CONSTRAINT valid_address EXPECT (
      (address IS NOT NULL AND city IS NOT NULL AND
       state IS NOT NULL AND zip_code IS NOT NULL) OR operation = "DELETE"),
    CONSTRAINT valid_email EXPECT (
      rlike(email, '^([a-zA-Z0-9_\\-\\.]+)@([a-zA-Z0-9_\\-\\.]+)\\.([a-zA-Z]{2,5})$')
      OR operation = "DELETE") ON VIOLATION DROP ROW
  )
  COMMENT "Feed de clientes limpio, listo para CDC"
AS
SELECT *, CAST(from_unixtime(timestamp) AS timestamp) AS timestamp_datetime
FROM STREAM bronze.customers_bronze_raw;

----------------------------------------------------------------------------------------------------------------
-- SILVER: CDC con AUTO CDC INTO (SCD Type 1 -- sin historial)
----------------------------------------------------------------------------------------------------------------
CREATE OR REFRESH STREAMING TABLE silver.customers_current;

CREATE FLOW customers_scd1_flow AS
AUTO CDC INTO silver.customers_current
FROM STREAM bronze.customers_bronze_clean
KEYS (customer_id)
APPLY AS DELETE WHEN operation = "DELETE"
SEQUENCE BY timestamp_datetime
COLUMNS * EXCEPT (operation, timestamp, _rescued_data)
STORED AS SCD TYPE 1;

----------------------------------------------------------------------------------------------------------------
-- (OPCIONAL) Version SCD Type 2 -- para practicar historial de versiones
-- Descomentar para reemplazar el flujo anterior. Requiere columnas __START_AT / __END_AT
-- automaticas que SDP agrega al usar STORED AS SCD TYPE 2.
----------------------------------------------------------------------------------------------------------------
-- CREATE OR REFRESH STREAMING TABLE silver.customers_history;
--
-- CREATE FLOW customers_scd2_flow AS
-- AUTO CDC INTO silver.customers_history
-- FROM STREAM bronze.customers_bronze_clean
-- KEYS (customer_id)
-- APPLY AS DELETE WHEN operation = "DELETE"
-- SEQUENCE BY timestamp_datetime
-- COLUMNS * EXCEPT (operation, timestamp, _rescued_data)
-- STORED AS SCD TYPE 2;
