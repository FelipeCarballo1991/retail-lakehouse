--------------------------------------------------------------------
-- 00 - Configuración del catálogo
--------------------------------------------------------------------

USE CATALOG retail_lakehouse;

--------------------------------------------------------------------
-- 01 - CTAS (CREATE TABLE AS) con read_files()
-- Ingesta batch, NO incremental. Ideal para una primera carga exploratoria.
-- Fuente: landing_zone/products (Parquet)
--------------------------------------------------------------------

-- 1) Explorar antes de crear la tabla (buena practica: LIMIT durante desarrollo)
SELECT * FROM read_files(
  :source || '/products',
  format => 'parquet',
  pathGlobFilter => '*.parquet'
) LIMIT 10;

-- 2) Crear la tabla Delta "bronze_products_ctas" de una sola vez
DROP TABLE IF EXISTS bronze.products_ctas;

CREATE TABLE bronze.products_ctas
SELECT *, current_timestamp() AS ingestion_time
FROM read_files(
  :source || '/products',
  format => 'parquet',
  pathGlobFilter => '*.parquet'
);

-- 3) Verificar
SELECT count(*) AS total_productos FROM bronze.products_ctas;
DESCRIBE TABLE EXTENDED bronze.products_ctas;

-- NOTA: si volves a correr este script completo despues de agregar productos
-- incrementales, CTAS relee TODO de nuevo (no es incremental). Para eso usa
-- 02_copy_into_products.sql o 03_autoloader_products.py
