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
from .lotes_inventario import router as lotes_inventario_router
from .materias_primas import router as materias_primas_router
from .movimientos_inventario import router as movimientos_inventario_router
from .ordenes_compra import router as ordenes_compra_router
from .proveedores import router as proveedores_router
from .recetas import router as recetas_router
from .cajas import router as cajas_router
from .clientes import router as clientes_router
from .mesas import router as mesas_router
from .metodos_pago import router as metodos_pago_router
from .pagos import router as pagos_router
from .pedidos import router as pedidos_router

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
api_router.include_router(lotes_inventario_router)   # /api/v1/lotes-inventario/*
api_router.include_router(materias_primas_router)    # /api/v1/materias-primas/*
api_router.include_router(movimientos_inventario_router) # /api/v1/movimientos-inventario/*
api_router.include_router(ordenes_compra_router)    # /api/v1/ordenes-compra/*
api_router.include_router(proveedores_router)      # /api/v1/proveedores/*
api_router.include_router(recetas_router)         # /api/v1/recetas/*
api_router.include_router(cajas_router)           # /api/v1/cajas/*
api_router.include_router(clientes_router)         # /api/v1/clientes/*
api_router.include_router(mesas_router)            # /api/v1/mesas/*
api_router.include_router(metodos_pago_router)     # /api/v1/metodos-pago/*
api_router.include_router(pagos_router)            # /api/v1/pagos/*
api_router.include_router(pedidos_router)          # /api/v1/pedidos/*