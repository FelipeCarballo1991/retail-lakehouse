--------------------------------------------------------------------
-- 02 - COPY INTO
-- Ingesta batch incremental e idempotente: los archivos ya cargados se saltan.
-- Fuente: landing_zone/products (carga inicial) + products_incremental (carga nueva)
--------------------------------------------------------------------

-- 1) Crear la tabla vacia (sin esquema fijo, se infiere del primer archivo)
CREATE TABLE IF NOT EXISTS bronze.products_copy_into;

-- 2) Primera carga: ingiere los productos iniciales
COPY INTO bronze.products_copy_into
FROM '${source}/products'
FILEFORMAT = PARQUET
PATTERN = 'part-00000.parquet'
COPY_OPTIONS ('mergeSchema' = 'true');

SELECT count(*) AS total_tras_carga_1 FROM bronze.products_copy_into;
-- Esperado: 50 filas

-- 3) Simular llegada de archivos nuevos: correr el mismo COPY INTO apuntando
--    a la carpeta incremental. Los productos ya ingeridos NO se reprocesan.
COPY INTO bronze.products_copy_into
FROM '${source}/products_incremental'
FILEFORMAT = PARQUET
COPY_OPTIONS ('mergeSchema' = 'true');

SELECT count(*) AS total_tras_carga_2 FROM bronze.products_copy_into;
-- Esperado: 65 filas (50 + 15 nuevos)

-- 4) Prueba de idempotencia: volver a correr el MISMO COPY INTO
--    num_affected_rows / num_inserted_rows deben ser 0 (ya se cargaron)
COPY INTO bronze.products_copy_into
FROM '${source}/products_incremental'
FILEFORMAT = PARQUET
COPY_OPTIONS ('mergeSchema' = 'true');
