import platform
import time
from datetime import UTC, datetime

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from loguru import logger
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.api.v1 import api_router
from app.config import settings
from app.core.limiter import limiter
from app.core.logger import setup_logger
from app.core.middleware import RequestLoggingMiddleware

# ── Inicializar logger PRIMERO — antes de cualquier otra cosa ─────────────────
setup_logger(debug=settings.debug)

_START_TIME = time.time()

# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="""
## Backend KDS — API

### Módulos
- **Auth** — Login, registro, invite, refresh, logout
- **Empresas** — CRUD completo con soft/hard delete y paginación
- **Sucursales** — CRUD con sincronización de asignaciones
- **Perfiles de Usuario** — CRUD con control de roles y estados
- **Usuarios × Sucursales** — Asignaciones con auto-promoción de principal

### Docs
- Swagger UI: `/docs` | ReDoc: `/redoc` | Health: `/health`
    """,
    docs_url="/docs",
    redoc_url="/redoc",
)

# ── Rate limiter — debe ir antes de los routers ───────────────────────────────
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# ── Logging de requests — intercepta todo ────────────────────────────────────
app.add_middleware(RequestLoggingMiddleware)

# ── CORS ─────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # en producción reemplazar con dominios específicos
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(api_router)

logger.info(
    "Servidor iniciado | app={app} | v={version} | debug={debug}",
    app=settings.app_name,
    version=settings.app_version,
    debug=settings.debug,
)


# ─── Ping ─────────────────────────────────────────────────────────────────────

@app.get("/", tags=["Health"], include_in_schema=False)
def root():
    return {"status": "ok", "version": settings.app_version}


# ─── Health check completo ────────────────────────────────────────────────────

@app.get("/health", tags=["Health"], summary="Health check completo")
def health_check():
    """
    Estado de todos los componentes del sistema.

    - `healthy`  → todo OK
    - `degraded` → funciona pero algo falla (Auth caído, variable faltante)
    - `unhealthy` → fallo crítico — HTTP 503
    """
    checks = {}
    overall = "healthy"

    # ── Supabase DB ───────────────────────────────────────────────────────────
    try:
        from app.database import get_supabase
        db = get_supabase()
        t = time.time()
        db.table("empresas").select("id").limit(1).execute()
        latency_ms = round((time.time() - t) * 1000, 2)
        checks["supabase_db"] = {"status": "ok", "latency_ms": latency_ms}
    except Exception as e:
        checks["supabase_db"] = {"status": "error", "message": str(e)[:120]}
        overall = "unhealthy"
        logger.error("Health: Supabase DB caída | error={error}", error=str(e)[:120])

    # ── Supabase Auth ─────────────────────────────────────────────────────────
    try:
        from app.database import get_supabase_admin
        db_admin = get_supabase_admin()
        t = time.time()
        db_admin.auth.admin.list_users()
        latency_ms = round((time.time() - t) * 1000, 2)
        checks["supabase_auth"] = {"status": "ok", "latency_ms": latency_ms}
    except Exception as e:
        checks["supabase_auth"] = {"status": "error", "message": str(e)[:120]}
        if overall == "healthy":
            overall = "degraded"
        logger.warning("Health: Supabase Auth degradado | error={error}", error=str(e)[:120])

    # ── Variables de entorno críticas ─────────────────────────────────────────
    issues = []
    if not getattr(settings, "supabase_service_key", None):
        issues.append("SUPABASE_SERVICE_KEY no definida")
    if not getattr(settings, "supabase_jwt_secret", None):
        issues.append("SUPABASE_JWT_SECRET no definida")
    if getattr(settings, "secret_key", "cambia-esto") == "cambia-esto":
        issues.append("SECRET_KEY usa valor por defecto — inseguro en producción")

    if issues:
        checks["config"] = {"status": "warning", "issues": issues}
        if overall == "healthy":
            overall = "degraded"
    else:
        checks["config"] = {"status": "ok"}

    # ── Tablas requeridas ─────────────────────────────────────────────────────
    tablas_requeridas = ["empresas", "sucursales", "perfiles_usuario", "usuarios_sucursales"]
    faltantes = []
    try:
        from app.database import get_supabase
        db = get_supabase()
        for tabla in tablas_requeridas:
            try:
                db.table(tabla).select("id").limit(1).execute()
            except Exception:
                faltantes.append(tabla)
        if faltantes:
            checks["tablas"] = {"status": "error", "faltantes": faltantes}
            overall = "unhealthy"
            logger.error("Health: tablas faltantes | tablas={tablas}", tablas=faltantes)
        else:
            checks["tablas"] = {"status": "ok", "count": len(tablas_requeridas)}
    except Exception as e:
        checks["tablas"] = {"status": "error", "message": str(e)[:120]}

    # ── Sistema ───────────────────────────────────────────────────────────────
    uptime_s = round(time.time() - _START_TIME, 1)
    system = {
        "python": platform.python_version(),
        "platform": platform.system(),
        "environment": "development" if settings.debug else "production",
        "uptime_seconds": uptime_s,
        "uptime_human": _fmt_uptime(uptime_s),
        "timestamp_utc": datetime.now(UTC).isoformat(),
    }

    status_code = 503 if overall == "unhealthy" else 200
    return JSONResponse(
        status_code=status_code,
        content={
            "status": overall,
            "version": settings.app_version,
            "components": checks,
            "system": system,
        },
    )


def _fmt_uptime(seconds: float) -> str:
    s = int(seconds)
    parts = []
    for unit, val in [("d", 86400), ("h", 3600), ("m", 60), ("s", 1)]:
        if s >= val:
            parts.append(f"{s // val}{unit}")
            s %= val
    return " ".join(parts) or "0s"