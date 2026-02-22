from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.api.v1 import api_router

app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="""
## Backend KDS conectado a Supabase 🚀

### Módulos disponibles
- **Empresas** — CRUD completo con soft delete y paginación
- **Sucursales** — *(próximamente)*
- **Perfiles de Usuario** — *(próximamente)*
- **Usuarios × Sucursales** — *(próximamente)*

### Documentación
- Swagger UI: `/docs`
- ReDoc: `/redoc`
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

# ─── Routers ─────────────────────────────────────────────────
app.include_router(api_router)


@app.get("/", tags=["Health"], summary="Health check")
def root():
    """Verifica que el servidor esté corriendo."""
    return {"status": "ok", "app": settings.app_name, "version": settings.app_version}