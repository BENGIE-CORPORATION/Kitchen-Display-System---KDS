# ══════════════════════════════════════════════════════════════
#  KDS Backend — Dockerfile
#  Stages: base → deps → development | production
# ══════════════════════════════════════════════════════════════

# ── Base ──────────────────────────────────────────────────────
FROM python:3.11-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
    && rm -rf /var/lib/apt/lists/*

# ── Deps ──────────────────────────────────────────────────────
# Copia solo los archivos de definición de dependencias primero
# para aprovechar el caché de Docker cuando el código cambia
# pero las dependencias no.
FROM base AS deps

# Renombrar a lowercase — Linux es case-sensitive, pip busca 'pyproject.toml'
COPY Pyproject.toml pyproject.toml
COPY README.md ./
# Instala las dependencias definidas en pyproject.toml
RUN pip install --no-cache-dir ".[dev]"

# ── Development ───────────────────────────────────────────────
# • El código fuente se monta como volumen (hot reload)
# • Uvicorn en modo --reload (observa cambios en /app/app)
FROM deps AS development

COPY . .

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "app.main:app", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--reload", \
     "--reload-dir", "/app/app"]

# ── Production ────────────────────────────────────────────────
# • Sin volúmenes — código baked en la imagen
# • 2 workers uvicorn para aprovechar múltiples CPUs
# • --proxy-headers para funcionar detrás de un reverse proxy / LB
FROM deps AS production

COPY . .
# Instala solo las dependencias de producción (sin extras dev)
RUN pip install --no-cache-dir .

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "app.main:app", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--workers", "2", \
     "--proxy-headers", \
     "--forwarded-allow-ips", "*"]
