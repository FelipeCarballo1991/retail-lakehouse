--------------------------------------------------------------------
-- 00 - SETUP: Catálogo, esquemas y volumen de Unity Catalog
-- Primer script a correr en un workspace nuevo (Databricks Free Edition).
-- Ejecutar UNA sola vez, en un notebook SQL, antes de cualquier otra etapa.
--------------------------------------------------------------------

-- 1) Catálogo raíz del proyecto
CREATE CATALOG IF NOT EXISTS retail_lakehouse;
USE CATALOG retail_lakehouse;

-- 2) Esquemas de la arquitectura medallion + landing zone
CREATE SCHEMA IF NOT EXISTS landing_zone
  COMMENT "Aterrizaje de archivos crudos antes de cualquier procesamiento";
CREATE SCHEMA IF NOT EXISTS bronze
  COMMENT "Datos crudos ingeridos, con metadata de origen";
CREATE SCHEMA IF NOT EXISTS silver
  COMMENT "Datos limpios, validados, con CDC aplicado";
CREATE SCHEMA IF NOT EXISTS gold
  COMMENT "Agregados de negocio listos para consumo";

-- 3) Volumen donde se sube manualmente la landing zone (ver Etapa 2)
CREATE VOLUME IF NOT EXISTS landing_zone.raw
  COMMENT "Landing zone: orders/status/customers/employees/products";

-- 4) Verificación
SHOW SCHEMAS IN retail_lakehouse;
SHOW VOLUMES IN retail_lakehouse.landing_zone;

-- Checkpoint esperado:
--   4 esquemas: landing_zone, bronze, silver, gold
--   1 volumen: raw (vacío por ahora, se puebla en la Etapa 2)
