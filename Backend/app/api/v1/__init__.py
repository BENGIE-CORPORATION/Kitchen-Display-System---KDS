from fastapi import APIRouter
from .auth import router as auth_router
from .empresas import router as empresas_router

# Próximos módulos:
# from .sucursales import router as sucursales_router
# from .perfiles import router as perfiles_router
# from .usuarios_sucursales import router as usuarios_sucursales_router

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(auth_router)       # /api/v1/auth/*
api_router.include_router(empresas_router)   # /api/v1/empresas/*
# api_router.include_router(sucursales_router)
# api_router.include_router(perfiles_router)
# api_router.include_router(usuarios_sucursales_router)