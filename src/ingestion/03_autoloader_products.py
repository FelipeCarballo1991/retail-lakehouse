# --------------------------------------------------------------------
# 03 - Auto Loader (cloudFiles) en Python
# El metodo mas escalable: procesa archivos nuevos incrementalmente,
# batch o streaming, con checkpointing y deteccion automatica de esquema.
# Fuente: landing_zone/products + products_incremental
# --------------------------------------------------------------------
import pyspark.sql.functions as F

source_path = spark.conf.get("source", "/Volumes/retail_lakehouse/landing_zone/products")
checkpoint_path = spark.conf.get("checkpoint", "/Volumes/retail_lakehouse/_checkpoints/products_autoloader")

(
    spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "parquet")
    .option("cloudFiles.schemaLocation", checkpoint_path)
    .load(source_path)
    .select(
        "*",
        F.current_timestamp().alias("ingestion_time"),
        "_metadata.file_name"
    )
    .writeStream
    .option("checkpointLocation", checkpoint_path)
    .trigger(availableNow=True)  # modo batch: procesa lo disponible y se detiene
    .toTable("bronze.products_autoloader")
)

# Verificacion:
# display(spark.table("bronze.products_autoloader"))
# Tras la primera corrida (source apuntando a /products): 50 filas
# Copiando los archivos de /products_incremental a la misma carpeta y
# re-ejecutando esta celda: solo se procesan los 15 archivos nuevos (checkpoint).

# --------------------------------------------------------------------
# Equivalente en SQL (Declarative Pipelines) -- referencia rapida:
# --------------------------------------------------------------------
# CREATE OR REFRESH STREAMING TABLE bronze.products_autoloader_sql
# AS SELECT * FROM STREAM read_files(
#   '${source}/products',
#   format => 'parquet'
# );
