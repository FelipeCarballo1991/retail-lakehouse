# =============================================================================
#
# Base: python:3.12.3-slim-bookworm
#
# Build:
#   docker build -t python-enviroment:local .
#
# Run:
#   docker run -it --rm -v "$(pwd)/workdir:/workspace" python-enviroment:local
#
# =============================================================================

FROM python:3.12.3-slim-bookworm

LABEL maintainer="Felipe Carballo <felipecarballo1991@gmail.com>" \
      project="retail-lakehouse" \
      description="Entorno para practicar las buenas practicas de databricks"

# -----------------------------------------------------------------------
# 1) Herramientas del sistema
# -----------------------------------------------------------------------
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        tesseract-ocr \
        tesseract-ocr-spa \
        libgl1 \
        git \
        curl \
        unzip \
        && \
    rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------
# 2) Directorio de trabajo
# -----------------------------------------------------------------------
WORKDIR /workspace

# -----------------------------------------------------------------------
# 3) Librerías Python
# -----------------------------------------------------------------------
COPY requirements-local.txt /workspace/requirements-local.txt

RUN python -m pip install --no-cache-dir --upgrade pip && \
    python -m pip install --no-cache-dir -r requirements-local.txt

# -----------------------------------------------------------------------
# 4) Databricks CLI
# -----------------------------------------------------------------------
RUN curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh

# -----------------------------------------------------------------------
# 5) Script de verificación
# -----------------------------------------------------------------------
COPY verify_env.py /workspace/verify_env.py

# -----------------------------------------------------------------------
# 6) Comando por defecto
# -----------------------------------------------------------------------
CMD ["python", "verify_env.py"]