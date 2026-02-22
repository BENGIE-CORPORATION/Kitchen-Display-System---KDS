from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routers import items

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="""
## Backend conectado a Supabase 🚀

Esta API fue generada con **FastAPI** y se conecta a **Supabase** como base de datos.

### Documentación disponible
- **Swagger UI**: `/docs`
- **ReDoc**: `/redoc`
- **OpenAPI JSON**: `/openapi.json`
    """,
    docs_url="/docs",
    redoc_url="/redoc",
)

# ─── CORS ────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Cambia a tu dominio en producción
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Routers ─────────────────────────────────────────────────
app.include_router(items.router, prefix="/api/v1")


# ─── Health Check ────────────────────────────────────────────
@app.get("/", tags=["Health"], summary="Health check")
def root():
    """Verifica que el servidor esté corriendo."""
    return {"status": "ok", "app": settings.app_name, "version": settings.app_version}