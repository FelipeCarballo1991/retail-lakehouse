--------------------------------------------------------------------
-- 04 - MERGE INTO
-- Upserts y deletes manuales, atomicos, sobre una tabla Delta existente.
-- Fuente: products/merge_target_products.csv (tabla actual)
--         products/merge_source_products.csv (cambios entrantes)
--------------------------------------------------------------------

-- 1) Cargar la tabla target (catalogo actual de productos)
CREATE OR REPLACE TABLE gold.products_catalog AS
SELECT * FROM read_files('${source}/products/merge_target_products.csv',
  format => 'csv', header => true);

-- 2) Cargar la tabla source (cambios: updates, delete, altas nuevas)
CREATE OR REPLACE TEMPORARY VIEW products_updates AS
SELECT * FROM read_files('${source}/products/merge_source_products.csv',
  format => 'csv', header => true);

SELECT * FROM gold.products_catalog ORDER BY product_id;
SELECT * FROM products_updates ORDER BY product_id;

-- 3) MERGE INTO: aplica update / delete / insert en una sola sentencia atomica
MERGE INTO gold.products_catalog target
USING products_updates source
ON target.product_id = source.product_id
WHEN MATCHED AND source.status = 'update' THEN
  UPDATE SET target.price = source.price, target.status = source.status
WHEN MATCHED AND source.status = 'delete' THEN
  DELETE
WHEN NOT MATCHED AND source.status = 'new' THEN
  INSERT (product_id, product_name, price, status)
  VALUES (source.product_id, source.product_name, source.price, source.status);

-- Resultado esperado:
-- - product_id 102 y 105: precio actualizado
-- - product_id 103: eliminado (discontinuado)
-- - product_id 200 y 201: nuevos productos insertados
SELECT * FROM gold.products_catalog ORDER BY product_id;

-- 4) Ver el historial de versiones de la tabla (time travel)
DESCRIBE HISTORY gold.products_catalog;

-- 5) (Opcional) Consultar una version anterior
-- SELECT * FROM gold.products_catalog VERSION AS OF 1;
