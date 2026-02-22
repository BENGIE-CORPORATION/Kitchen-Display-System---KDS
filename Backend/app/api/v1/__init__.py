from fastapi import APIRouter
from .empresas import router as empresas_router

# Aquí irán todos los routers de v1
# from .sucursales import router as sucursales_router
# from .perfiles_usuario import router as perfiles_router
# from .usuarios_sucursales import router as usuarios_sucursales_router

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(empresas_router)
# api_router.include_router(sucursales_router)
# api_router.include_router(perfiles_router)
# api_router.include_router(usuarios_sucursales_router)