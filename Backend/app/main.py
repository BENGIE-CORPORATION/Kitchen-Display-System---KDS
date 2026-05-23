import platform
import time
from datetime import UTC, datetime

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from loguru import logger
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from prometheus_fastapi_instrumentator import Instrumentator

from app.api.v1 import api_router
from app.config import settings
from app.core.limiter import limiter
from app.core.logger import setup_logger
from app.core.middleware import RequestLoggingMiddleware

# ── Logger — debe ser lo primero ──────────────────────────────────────────────
setup_logger(debug=settings.debug)

# ── Validación de settings en producción ──────────────────────────────────────
if settings.is_production:
    errors = settings.validate_production_settings()
    if errors:
        for err in errors:
            logger.critical("CONFIG ERROR: {err}", err=err)
        raise RuntimeError(
            f"Configuración inválida para producción:\n" + "\n".join(f"  - {e}" for e in errors)
        )

_START_TIME = time.time()

# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="""
## Backend KDS — API

### Módulos
- **Auth** — Login, registro, invite, refresh, logout, change-password
- **Empresas** — CRUD completo con soft/hard delete y paginación
- **Sucursales** — CRUD con sincronización de asignaciones
- **Perfiles de Usuario** — CRUD con control de roles y estados
- **Usuarios × Sucursales** — Asignaciones con auto-promoción de principal

### Docs
- Swagger UI: `/docs` | ReDoc: `/redoc` | Health: `/health`
    """,
    docs_url="/docs" if not settings.is_production else None,   # desactivar docs en prod
    redoc_url="/redoc" if not settings.is_production else None,
)

# ── Rate limiter ──────────────────────────────────────────────────────────────
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# ── Logging de requests ───────────────────────────────────────────────────────
app.add_middleware(RequestLoggingMiddleware)

# ── CORS ─────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # en producción: reemplazar con dominios reales
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(api_router)

# ── Prometheus metrics ────────────────────────────────────────────────────────
# Instrumenta automáticamente todas las rutas HTTP (latencia, requests, status).
# Expone GET /metrics en formato texto que Prometheus puede scrapear.
Instrumentator(
    should_group_status_codes=False,
    excluded_handlers=["/metrics"],   # no medir el propio endpoint de métricas
).instrument(app).expose(app, endpoint="/metrics", tags=["Observabilidad"])

logger.info(
    "Servidor iniciado | app={app} | v={version} | env={env} | debug={debug}",
    app=settings.app_name,
    version=settings.app_version,
    env=settings.app_env,
    debug=settings.debug,
)


# ─── Exception handlers globales ─────────────────────────────────────────────

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """
    Captura errores de validación de Pydantic (422).
    Los formatea de forma consistente con el resto de errores de la app.
    """
    errors = []
    for error in exc.errors():
        field = " → ".join(str(loc) for loc in error["loc"] if loc != "body")
        errors.append({"field": field, "message": error["msg"]})

    logger.warning(
        "Validación fallida | {method} {path} | errores={errors}",
        method=request.method,
        path=request.url.path,
        errors=errors,
    )

    return JSONResponse(
        status_code=422,
        content={
            "error": "VALIDATION_ERROR",
            "detail": "Los datos enviados no son válidos",
            "fields": errors,
        },
    )


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """
    Captura cualquier excepción no manejada.
    - Loguea el stacktrace completo en errors.log
    - Retorna 500 genérico al cliente (sin exponer internos)
    """
    logger.exception(
        "Excepción no manejada | {method} {path} | {exc_type}: {exc}",
        method=request.method,
        path=request.url.path,
        exc_type=type(exc).__name__,
        exc=str(exc),
    )

    # En desarrollo muestra el error real, en producción respuesta genérica
    detail = str(exc) if settings.debug else "Error interno del servidor"

    return JSONResponse(
        status_code=500,
        content={"error": "INTERNAL_ERROR", "detail": detail},
    )


# ─── Ping ─────────────────────────────────────────────────────────────────────

@app.get("/", tags=["Health"], include_in_schema=False)
def root():
    return {"status": "ok", "version": settings.app_version, "env": settings.app_env}


# ─── Health check completo ────────────────────────────────────────────────────

@app.get("/health", tags=["Health"], summary="Health check completo")
def health_check():
    """
    Estado de todos los componentes.
    - `healthy`  → todo OK (HTTP 200)
    - `degraded` → funciona con limitaciones (HTTP 200)
    - `unhealthy` → fallo crítico (HTTP 503)
    """
    checks = {}
    overall = "healthy"

    # ── Supabase DB ───────────────────────────────────────────────────────────
    try:
        from app.database import get_supabase
        db = get_supabase()
        t = time.time()
        db.table("empresas").select("id").limit(1).execute()
        checks["supabase_db"] = {"status": "ok", "latency_ms": round((time.time() - t) * 1000, 2)}
    except Exception as e:
        checks["supabase_db"] = {"status": "error", "message": str(e)[:120]}
        overall = "unhealthy"
        logger.error("Health: Supabase DB caída | {error}", error=str(e)[:120])

    # ── Supabase Auth ─────────────────────────────────────────────────────────
    try:
        from app.database import get_supabase_admin
        db_admin = get_supabase_admin()
        t = time.time()
        db_admin.auth.admin.list_users()
        checks["supabase_auth"] = {"status": "ok", "latency_ms": round((time.time() - t) * 1000, 2)}
    except Exception as e:
        checks["supabase_auth"] = {"status": "error", "message": str(e)[:120]}
        if overall == "healthy":
            overall = "degraded"
        logger.warning("Health: Supabase Auth degradado | {error}", error=str(e)[:120])

    # ── Config ────────────────────────────────────────────────────────────────
    config_errors = settings.validate_production_settings() if settings.is_production else []
    if config_errors:
        checks["config"] = {"status": "warning", "issues": config_errors}
        if overall == "healthy":
            overall = "degraded"
    else:
        checks["config"] = {"status": "ok"}

    # ── Tablas ────────────────────────────────────────────────────────────────
    tablas = ["empresas", "sucursales", "perfiles_usuario", "usuarios_sucursales"]
    faltantes = []
    try:
        from app.database import get_supabase
        db = get_supabase()
        for tabla in tablas:
            try:
                db.table(tabla).select("id").limit(1).execute()
            except Exception:
                faltantes.append(tabla)
        if faltantes:
            checks["tablas"] = {"status": "error", "faltantes": faltantes}
            overall = "unhealthy"
        else:
            checks["tablas"] = {"status": "ok", "count": len(tablas)}
    except Exception as e:
        checks["tablas"] = {"status": "error", "message": str(e)[:120]}

    # ── Sistema ───────────────────────────────────────────────────────────────
    uptime_s = round(time.time() - _START_TIME, 1)
    system = {
        "python": platform.python_version(),
        "environment": settings.app_env,
        "uptime_seconds": uptime_s,
        "uptime_human": _fmt_uptime(uptime_s),
        "timestamp_utc": datetime.now(UTC).isoformat(),
    }

    return JSONResponse(
        status_code=503 if overall == "unhealthy" else 200,
        content={"status": overall, "version": settings.app_version, "components": checks, "system": system},
    )


def _fmt_uptime(seconds: float) -> str:
    s = int(seconds)
    parts = []
    for unit, val in [("d", 86400), ("h", 3600), ("m", 60), ("s", 1)]:
        if s >= val:
            parts.append(f"{s // val}{unit}")
            s %= val
    return " ".join(parts) or "0s"