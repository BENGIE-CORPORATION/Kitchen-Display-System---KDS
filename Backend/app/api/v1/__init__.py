from fastapi import APIRouter

from .auth import router as auth_router
from .combos import router as combos_router
from .categorias import router as categorias_router
from .empresas import router as empresas_router
from .perfiles import router as perfiles_router
from .productos import router as productos_router
from .sucursales import router as sucursales_router
from .usuarios_sucursales import router as usuarios_sucursales_router
from .variantes_productos import router as variantes_producto_router

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(auth_router)                # /api/v1/auth/*
api_router.include_router(empresas_router)            # /api/v1/empresas/*
api_router.include_router(sucursales_router)          # /api/v1/sucursales/*
api_router.include_router(perfiles_router)            # /api/v1/perfiles/*
api_router.include_router(categorias_router)          # /api/v1/categorias/*
api_router.include_router(productos_router)           # /api/v1/productos/*
api_router.include_router(variantes_producto_router)  # /api/v1/productos/{id}/variantes/*
api_router.include_router(combos_router)              # /api/v1/productos/{id}/combos/*
api_router.include_router(usuarios_sucursales_router) # /api/v1/usuarios-sucursales/*