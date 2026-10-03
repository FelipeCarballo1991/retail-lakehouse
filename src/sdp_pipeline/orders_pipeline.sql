--------------------------------------------------------------------
-- ORDERS PIPELINE — Bronze -> Silver -> Gold
-- Parte del proyecto "Retail Lakehouse"
-- Fuente: ${source}/orders  (landing_zone/orders montada como Volume)
--------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------
-- BRONZE: ingesta incremental de los JSON de pedidos
----------------------------------------------------------------------------------------------------------------
CREATE OR REFRESH STREAMING TABLE bronze.orders_bronze
  COMMENT "Ingesta incremental de archivos JSON de pedidos desde la landing zone"
  TBLPROPERTIES (
    "quality" = "bronze",
    "pipelines.reset.allowed" = false
  )
AS
SELECT
  *,
  current_timestamp() AS processing_time,
  _metadata.file_name AS source_file
FROM STREAM read_files(
  "${source}/orders",
  format => 'JSON'
);

----------------------------------------------------------------------------------------------------------------
-- SILVER: limpieza + calidad de datos (Expectations)
----------------------------------------------------------------------------------------------------------------
CREATE OR REFRESH STREAMING TABLE silver.orders_silver
  (
    CONSTRAINT valid_notifications EXPECT (notifications IN ('Y','N')),
    CONSTRAINT valid_date EXPECT (order_timestamp > "2026-01-01") ON VIOLATION DROP ROW,
    CONSTRAINT valid_id EXPECT (customer_id IS NOT NULL) ON VIOLATION FAIL UPDATE
  )
  COMMENT "Pedidos limpios y validados"
  TBLPROPERTIES ("quality" = "silver")
AS
SELECT
  order_id,
  timestamp(order_timestamp) AS order_timestamp,
  customer_id,
  store_region,
  notifications
FROM STREAM bronze.orders_bronze;

----------------------------------------------------------------------------------------------------------------
-- GOLD: agregación de pedidos por fecha (Materialized View)
----------------------------------------------------------------------------------------------------------------
CREATE OR REFRESH MATERIALIZED VIEW gold.orders_by_date
  COMMENT "Total de pedidos por dia para reporting"
  TBLPROPERTIES ("quality" = "gold")
AS
SELECT
  date(order_timestamp) AS order_date,
  store_region,
  count(*) AS total_daily_orders
FROM silver.orders_silver
GROUP BY date(order_timestamp), store_region;
