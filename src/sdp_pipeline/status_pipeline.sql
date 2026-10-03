--------------------------------------------------------------------
-- STATUS PIPELINE — Bronze -> Silver -> Gold (join con orders)
-- Parte del proyecto "Retail Lakehouse"
-- Fuente: ${source}/status  (landing_zone/status montada como Volume)
--------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------
-- BRONZE
----------------------------------------------------------------------------------------------------------------
CREATE OR REFRESH STREAMING TABLE bronze.status_bronze
  COMMENT "Ingesta incremental de estados de pedidos"
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
  "${source}/status",
  format => "json"
);

----------------------------------------------------------------------------------------------------------------
-- SILVER
----------------------------------------------------------------------------------------------------------------
CREATE OR REFRESH STREAMING TABLE silver.status_silver
(
  CONSTRAINT valid_order_status
    EXPECT (
      order_status IN (
        'on the way', 'canceled', 'delivered', 'placed', 'preparing'
      )
    )
)
COMMENT "Estados de pedido con timestamp normalizado"
TBLPROPERTIES ("quality" = "silver")
AS
SELECT
  order_id,
  order_status,
  timestamp(status_timestamp) AS order_status_timestamp
FROM STREAM bronze.status_bronze;

----------------------------------------------------------------------------------------------------------------
-- GOLD: join orders + status (Materialized View), y vistas de negocio derivadas
----------------------------------------------------------------------------------------------------------------
CREATE OR REFRESH MATERIALIZED VIEW gold.full_order_info
  COMMENT "Pedidos con cada estado individual (join completo)"
  TBLPROPERTIES ("quality" = "gold")
AS
SELECT
  o.order_id,
  o.order_timestamp,
  o.store_region,
  s.order_status,
  s.order_status_timestamp
FROM silver.status_silver s
INNER JOIN silver.orders_silver o
  ON o.order_id = s.order_id;

CREATE OR REFRESH MATERIALIZED VIEW gold.cancelled_orders
  COMMENT "Pedidos cancelados con dias transcurridos hasta la cancelacion"
  TBLPROPERTIES ("quality" = "gold")
AS
SELECT
  order_id, order_timestamp, store_region, order_status, order_status_timestamp,
  datediff(DAY, order_timestamp, order_status_timestamp) AS days_to_cancel
FROM gold.full_order_info
WHERE order_status = 'canceled';

CREATE OR REFRESH MATERIALIZED VIEW gold.delivered_orders
  COMMENT "Pedidos entregados con dias transcurridos hasta la entrega"
  TBLPROPERTIES ("quality" = "gold")
AS
SELECT
  order_id, order_timestamp, store_region, order_status, order_status_timestamp,
  datediff(DAY, order_timestamp, order_status_timestamp) AS days_to_delivery
FROM gold.full_order_info
WHERE order_status = 'delivered';
