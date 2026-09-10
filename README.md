# 🏬 Retail Lakehouse — Proyecto Integrador de Databricks Data Engineering

Proyecto práctico de portfolio que integra los 4 cursos de la ruta **Databricks Data Engineer Associate ITL**
en un único pipeline de datos end-to-end, siguiendo la arquitectura **Landing Zone → Bronze → Silver → Gold**.

Pensado para desplegarse y practicarse íntegramente en **[Databricks Free Edition](https://www.databricks.com/product/pricing/community-edition)** (o cualquier workspace personal), sin dependencias de ningún entorno corporativo.

## 🎯 Qué simula este proyecto

Una empresa de **retail** que necesita:
- Ingerir su **catálogo de productos** desde archivos Parquet en la nube.
- Procesar **pedidos** y sus **estados** (placed → preparing → delivered/canceled) de forma incremental.
- Mantener actualizado su **padrón de clientes** vía Change Data Capture (altas, bajas, modificaciones).
- Sincronizar la **nómina de empleados** de cada tienda con el mismo patrón de CDC.
- Orquestar todo el proceso con control de calidad, procesamiento paralelo por región y notificaciones.
- Tener testing automatizado y CI/CD, como cualquier proyecto de software profesional.

## 🗺️ Arquitectura

```
                    ┌─────────────────┐
   Archivos nuevos  │   LANDING ZONE   │  data/landing_zone/
   (JSON/CSV/Parquet)│  (cloud storage) │  orders · status · customers · employees · products
                    └────────┬─────────┘
                             │  read_files() / Auto Loader / COPY INTO
                             ▼
                    ┌─────────────────┐
                    │      BRONZE      │  Ingesta cruda + metadata (incremental, Streaming Tables)
                    └────────┬─────────┘
                             │  Expectations (WARN/DROP/FAIL) + AUTO CDC INTO
                             ▼
                    ┌─────────────────┐
                    │      SILVER      │  Datos limpios, validados, CDC aplicado (SCD Tipo 1)
                    └────────┬─────────┘
                             │  Agregaciones, joins (Materialized Views)
                             ▼
                    ┌─────────────────┐
                    │       GOLD       │  Métricas de negocio listas para consumo/BI
                    └─────────────────┘

   Todo orquestado por: Lakeflow Jobs (databricks.yml)
   Todo testeado por:   pytest (unit + integration) + CI en GitHub Actions
```

## 📚 Mapa: curso → concepto → dónde vive en este repo

| Curso (Databricks Academy) | Conceptos aplicados | Archivos del proyecto |
|---|---|---|
| **Build Data Pipelines with Apache Spark Declarative Pipelines** | Streaming Tables, Materialized Views, Expectations, AUTO CDC INTO (SCD 1/2) | `src/sdp_pipeline/*.sql` |
| **Deploy Workloads with Lakeflow Jobs** | Jobs/Tasks, DAG, If/Else, For Each Task, Task Values, triggers, notificaciones | `databricks.yml`, `src/jobs/notebooks/*.py` |
| **Data Ingestion with LakeFlow Connect** | CTAS, COPY INTO, Auto Loader, MERGE INTO | `src/ingestion/*.sql`, `src/ingestion/*.py` |
| **DevOps Essentials for Data Engineering** | Testing pyramid (unit/integration/system), CI/CD | `tests/`, `.github/workflows/ci.yml` |

Las guías conceptuales completas de cada curso (teoría + ejercicios explicados) están en [`docs/`](./docs).

## 📁 Estructura del repositorio

```
retail_lakehouse/
├── README.md                          <- este archivo
├── databricks.yml                     <- Databricks Asset Bundle (Job + Pipeline como código)
├── requirements.txt
├── pytest.ini
├── scripts/
│   └── generate_landing_zone.py       <- genera todos los archivos de entrada
├── data/landing_zone/                 <- ARCHIVOS DE ENTRADA (landing zone simulada)
│   ├── orders/                        <- orders_00.json, orders_01.json
│   ├── status/                        <- status_00.json, status_01.json
│   ├── customers/                     <- customers_00.json, customers_01.json (CDC)
│   ├── employees/                     <- employees_1.csv, employees_2.csv (CDC lab)
│   └── products/ + products_incremental/  <- Parquet + CSV para CTAS/COPY INTO/Auto Loader/MERGE INTO
├── src/
│   ├── sdp_pipeline/                  <- Bronze/Silver/Gold en SQL (Spark Declarative Pipelines)
│   ├── ingestion/                     <- Demos de CTAS, COPY INTO, Auto Loader, MERGE INTO
│   ├── jobs/notebooks/                <- Notebooks orquestados por el Job (if/else, for each)
│   └── common/transformations.py      <- Lógica de negocio testeable (funciones puras)
├── tests/
│   ├── unit/                          <- Pirámide de testing: base (rápidos, aislados)
│   ├── integration/                   <- Pirámide de testing: medio (componentes interactuando)
│   └── system/                        <- Pirámide de testing: tope (Job real end-to-end)
├── .github/workflows/ci.yml           <- CI: corre pytest en cada push/PR
└── docs/                              <- Guías conceptuales (Word) de cada curso
```

## 🚀 Cómo levantar el proyecto en Databricks Free Edition

### 1. Crear la cuenta y el workspace
1. Registrate en [Databricks Free Edition](https://www.databricks.com/product/pricing/community-edition) (o usá un workspace ya existente donde tengas permisos de `Create Catalog`).
2. Anotá tu **workspace URL** (`https://<algo>.cloud.databricks.com`).

### 2. Crear el catálogo y la landing zone en Unity Catalog
En un notebook nuevo, corré:
```sql
CREATE CATALOG IF NOT EXISTS retail_lakehouse;
USE CATALOG retail_lakehouse;

CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;
CREATE SCHEMA IF NOT EXISTS landing_zone;

CREATE VOLUME IF NOT EXISTS landing_zone.raw;
```

### 3. Subir los archivos de entrada
1. Cloná este repo (o descargá el zip) en tu máquina.
2. Corré `python scripts/generate_landing_zone.py` para (re)generar los archivos en `data/landing_zone/` (ya vienen generados en el repo, este paso es opcional).
3. Desde **Catalog Explorer** en Databricks, subí cada subcarpeta (`orders/`, `status/`, `customers/`, `employees/`, `products/`) al volumen `retail_lakehouse.landing_zone.raw`, respetando la misma estructura de carpetas.

> 💡 Para practicar la incrementalidad (Guías SDP y Data Ingestion), subí primero solo los archivos `_00`/`_1`/`part-00000`, corré el pipeline, y **después** subí los `_01`/`_2`/`products_incremental` para ver cómo se procesan solo los datos nuevos.

### 4. Desplegar con Databricks Asset Bundles (recomendado)
```bash
pip install databricks-cli
databricks configure --token   # pegá tu workspace URL y un Personal Access Token

# Ajustá databricks.yml: workspace.host y variables.landing_zone_volume

databricks bundle validate -t dev
databricks bundle deploy -t dev
databricks bundle run retail_pipeline_job -t dev
```

### 5. (Alternativa manual, sin DABs)
Si preferís no usar el CLI, podés crear el pipeline y el job manualmente desde la UI:
1. **Jobs & Pipelines → Create → ETL Pipeline**: subí los archivos de `src/sdp_pipeline/` como código fuente, configurá `source` = ruta de tu volumen.
2. **Jobs & Pipelines → Create → Job**: recreá las tasks descritas en `databricks.yml` (`check_new_files` → `quality_gate` → `ingest_products` + `run_sdp_pipeline` → `for_each_region` → `notify_summary`).

## 🧪 Correr los tests localmente

```bash
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt

pytest tests/unit -v          # rápidos, sin dependencias externas
pytest tests/integration -v   # leen los archivos reales de data/landing_zone/
# tests/system/ requiere credenciales de un workspace real, correr manualmente
```

El mismo comando corre automáticamente en cada push/PR vía [GitHub Actions](./.github/workflows/ci.yml).

## 📖 Guías conceptuales incluidas

| Guía | Contenido |
|---|---|
| `docs/Guia1_Fundamentos_Databricks.docx` | Lakehouse, Unity Catalog, Lakeflow, Arquitectura Medallion |
| `docs/Guia2_SparkDeclarativePipelines.docx` | Streaming Tables, Materialized Views, Views |
| `docs/Guia3_Calidad_Produccion.docx` | Expectations, documentación, producción, event log |
| `docs/Guia4_CDC_AutoCDCInto.docx` | Change Data Capture, SCD Tipo 1/2 |
| `docs/Guia5_Practica_Replicacion.docx` | Cómo replicar el proyecto SDP paso a paso |
| `docs/Guia6_LakeflowJobs_Teoria_Practica.docx` | Jobs, Tasks, DAG, triggers + proyecto práctico |
| `docs/Guia7_DataIngestion_Teoria_Practica.docx` | CTAS, COPY INTO, Auto Loader, MERGE INTO + práctica |
| `docs/Guia8_DevOps_Essentials_Practica.docx` | CI/CD, testing pyramid + implementación real |

## 🛠️ Stack técnico

- **Databricks Free Edition** (Serverless compute)
- **Unity Catalog** (gobierno de datos)
- **Delta Lake** (almacenamiento transaccional)
- **Apache Spark Declarative Pipelines (SDP)** — SQL declarativo
- **Lakeflow Jobs** — orquestación (Databricks Asset Bundles / YAML)
- **pytest + PySpark local** — testing
- **GitHub Actions** — CI/CD

## 📄 Licencia

MIT — usá este proyecto libremente como base de estudio o portfolio.

---
*Proyecto armado como material de estudio para la certificación Databricks Data Engineer Associate, integrando los 4 cursos de la ruta oficial de Databricks Academy en un solo caso de uso práctico y reproducible.*
