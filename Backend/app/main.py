import platform
import time
from datetime import UTC, datetime

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1 import api_router
from app.config import settings

# Timestamp de arranque del proceso — para calcular uptime
_START_TIME = time.time()

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
- Swagger UI: `/docs`
- ReDoc: `/redoc`
- Health: `/health`
    """,
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)


# ─── Health check básico ──────────────────────────────────────────────────────

@app.get("/", tags=["Health"], summary="Ping", include_in_schema=False)
def root():
    return {"status": "ok", "version": settings.app_version}


# ─── Health check completo ────────────────────────────────────────────────────

@app.get("/health", tags=["Health"], summary="Health check completo")
def health_check():
    """
    Verifica el estado de todos los componentes del sistema.

    Retorna:
    - **status**: `healthy` | `degraded` | `unhealthy`
    - **uptime_seconds**: segundos desde que arrancó el proceso
    - **components**: estado individual de cada dependencia
    - **system**: info del entorno de ejecución

    `degraded` = el servidor funciona pero alguna dependencia tiene problemas.
    `unhealthy` = fallo crítico, el servidor no puede operar correctamente.
    """
    checks = {}
    overall = "healthy"

    # ── 1. Supabase DB (tabla más usada) ──────────────────────────────────────
    try:
        from app.database import get_supabase
        db = get_supabase()
        start = time.time()
        result = db.table("empresas").select("id").limit(1).execute()
        latency_ms = round((time.time() - start) * 1000, 2)
        checks["supabase_db"] = {
            "status": "ok",
            "latency_ms": latency_ms,
            "message": "Conexión a PostgreSQL operativa",
        }
    except Exception as e:
        checks["supabase_db"] = {
            "status": "error",
            "latency_ms": None,
            "message": f"No se puede conectar a Supabase: {str(e)[:120]}",
        }
        overall = "unhealthy"

    # ── 2. Supabase Auth ──────────────────────────────────────────────────────
    try:
        from app.database import get_supabase_admin
        db_admin = get_supabase_admin()
        start = time.time()
        # Listar 1 usuario — confirma que service_role key funciona
        db_admin.auth.admin.list_users()
        latency_ms = round((time.time() - start) * 1000, 2)
        checks["supabase_auth"] = {
            "status": "ok",
            "latency_ms": latency_ms,
            "message": "Supabase Auth operativo (service_role válida)",
        }
    except Exception as e:
        checks["supabase_auth"] = {
            "status": "error",
            "latency_ms": None,
            "message": f"Fallo en Auth: {str(e)[:120]}",
        }
        # Auth caído es degraded, no unhealthy — las queries normales siguen funcionando
        if overall == "healthy":
            overall = "degraded"

    # ── 3. Configuración — detectar variables críticas faltantes ──────────────
    config_issues = []
    if not settings.supabase_url:
        config_issues.append("SUPABASE_URL no definida")
    if not settings.supabase_key:
        config_issues.append("SUPABASE_KEY no definida")
    if not getattr(settings, "supabase_service_key", None):
        config_issues.append("SUPABASE_SERVICE_KEY no definida — /auth/invite no funcionará")
    if not getattr(settings, "supabase_jwt_secret", None):
        config_issues.append("SUPABASE_JWT_SECRET no definida — autenticación no funcionará")
    if getattr(settings, "secret_key", "cambia-esto") == "cambia-esto":
        config_issues.append("SECRET_KEY usa el valor por defecto — inseguro en producción")

    if config_issues:
        checks["config"] = {
            "status": "warning" if overall != "unhealthy" else "error",
            "issues": config_issues,
        }
        if overall == "healthy":
            overall = "degraded"
    else:
        checks["config"] = {
            "status": "ok",
            "message": "Todas las variables de entorno requeridas están definidas",
        }

    # ── 4. Tablas críticas — verificar que existen ────────────────────────────
    tablas_requeridas = [
        "empresas",
        "sucursales",
        "perfiles_usuario",
        "usuarios_sucursales",
    ]
    tablas_ok = []
    tablas_faltantes = []

    try:
        from app.database import get_supabase
        db = get_supabase()
        for tabla in tablas_requeridas:
            try:
                db.table(tabla).select("id").limit(1).execute()
                tablas_ok.append(tabla)
            except Exception:
                tablas_faltantes.append(tabla)

        if tablas_faltantes:
            checks["tablas"] = {
                "status": "error",
                "ok": tablas_ok,
                "faltantes": tablas_faltantes,
                "message": "Ejecutar el SQL de creación de tablas en Supabase",
            }
            overall = "unhealthy"
        else:
            checks["tablas"] = {
                "status": "ok",
                "tablas": tablas_ok,
                "message": f"{len(tablas_ok)} tablas verificadas",
            }
    except Exception as e:
        checks["tablas"] = {
            "status": "error",
            "message": f"No se pudo verificar tablas: {str(e)[:120]}",
        }

    # ── 5. Sistema ────────────────────────────────────────────────────────────
    uptime_seconds = round(time.time() - _START_TIME, 1)
    uptime_human = _format_uptime(uptime_seconds)

    system_info = {
        "python_version": platform.python_version(),
        "platform": platform.system(),
        "environment": "development" if settings.debug else "production",
        "uptime_seconds": uptime_seconds,
        "uptime_human": uptime_human,
        "timestamp_utc": datetime.now(UTC).isoformat(),
    }

    # ── Respuesta final ───────────────────────────────────────────────────────
    status_code_map = {"healthy": 200, "degraded": 200, "unhealthy": 503}

    from fastapi.responses import JSONResponse
    return JSONResponse(
        status_code=status_code_map[overall],
        content={
            "status": overall,
            "version": settings.app_version,
            "components": checks,
            "system": system_info,
        },
    )


def _format_uptime(seconds: float) -> str:
    """Convierte segundos a formato legible: '2d 3h 45m 10s'."""
    seconds = int(seconds)
    days = seconds // 86400
    hours = (seconds % 86400) // 3600
    minutes = (seconds % 3600) // 60
    secs = seconds % 60

    parts = []
    if days:
        parts.append(f"{days}d")
    if hours:
        parts.append(f"{hours}h")
    if minutes:
        parts.append(f"{minutes}m")
    parts.append(f"{secs}s")
    return " ".join(parts)