"""
Router de Productos — solo lógica HTTP.
Toda la lógica de base de datos vive en app/crud/crud_productos.py

Seguridad:
  GET    /productos/                          → autenticado (filtra por empresa)
  GET    /productos/{id}                      → autenticado + misma empresa
  GET    /productos/sucursal/{sucursal_id}    → autenticado + acceso a esa sucursal
  POST   /productos/                          → admin_empresa o super_admin
  PATCH  /productos/{id}                      → admin_empresa o super_admin
  DELETE /productos/{id}                      → admin_empresa o super_admin  [soft]
  DELETE /productos/{id}/hard                 → solo super_admin

  --- Productos × Sucursal (precios y stock) ---
  GET    /productos/{id}/sucursales/{suc_id}  → admin_empresa o super_admin
  POST   /productos/{id}/sucursales           → admin_empresa o super_admin
  PATCH  /productos/sucursales/{ps_id}        → admin_empresa o super_admin
  DELETE /productos/sucursales/{ps_id}        → admin_empresa o super_admin
"""

from datetime import UTC, datetime
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request, status
from loguru import logger
from supabase import Client

from ...core.exceptions.http_exceptions import (
    BadRequestException,
    DuplicateValueException,
    NotFoundException,
)
from ...core.limiter import get_user_id_from_token, limiter
from ...core.pagination import PaginatedResponse
from ...core.security import (
    get_current_admin,
    get_current_superadmin,
    get_current_user,
    verify_empresa_access,
    verify_sucursal_access,
)
from ...crud.crud_categorias import get_categoria
from ...crud.crud_productos import (
    create_producto,
    create_producto_sucursal,
    delete_producto_sucursal,
    deshabilitar_producto_en_sucursales,
    get_producto,
    get_producto_sucursal,
    get_producto_sucursal_by_id,
    get_productos,
    get_productos_por_sucursal,
    hard_delete_producto,
    producto_codigo_exists,
    producto_sucursal_exists,
    soft_delete_producto,
    update_producto,
    update_producto_sucursal,
)
from ...crud.crud_sucursales import get_sucursal
from ...database import get_supabase
from ...schemas.producto import (
    ProductoCreate,
    ProductoCreateInternal,
    ProductoRead,
    ProductoSucursalCreate,
    ProductoSucursalRead,
    ProductoSucursalUpdate,
    ProductoSucursalUpdateInternal,
    ProductoUpdate,
    ProductoUpdateInternal,
)

router = APIRouter(prefix="/productos", tags=["Productos"])


# ─── GET /productos/ ──────────────────────────────────────────────────────────

@router.get(
    "/",
    response_model=PaginatedResponse[ProductoRead],
    summary="Listar productos",
    description="Empleado/admin ven solo su empresa. super_admin debe especificar empresa_id.",
)
def read_productos(
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 20,
    order_by: str = "created_at",
    order_desc: bool = True,
    categoria_id: UUID | None = None,
    tipo_producto: str | None = None,
    estado: str | None = None,
    es_vendible: bool | None = None,
    search: str | None = None,
    empresa_id: UUID | None = None,
) -> dict:
    if current_user["rol_global"] == "super_admin":
        if not empresa_id:
            raise BadRequestException("super_admin debe especificar empresa_id como query param")
        target = empresa_id
    else:
        target = UUID(str(current_user["empresa_id"]))

    return get_productos(
        db=db, empresa_id=target, page=page, items_per_page=items_per_page,
        order_by=order_by, order_desc=order_desc, categoria_id=categoria_id,
        tipo_producto=tipo_producto, estado=estado, es_vendible=es_vendible, search=search,
    )


# ─── GET /productos/sucursal/{sucursal_id} ────────────────────────────────────

@router.get(
    "/sucursal/{sucursal_id}",
    response_model=PaginatedResponse[ProductoSucursalRead],
    summary="Listar productos con precios y stock de una sucursal",
)
def read_productos_sucursal(
    sucursal_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 20,
    disponible_venta: bool | None = None,
) -> dict:
    sucursal = get_sucursal(db, sucursal_id)
    if not sucursal:
        raise NotFoundException("Sucursal no encontrada")

    if current_user["rol_global"] == "empleado":
        verify_sucursal_access(db, current_user, sucursal_id)   # 🔒 asignación activa
    else:
        verify_empresa_access(current_user, UUID(str(sucursal["empresa_id"])))  # 🔒 su empresa

    return get_productos_por_sucursal(
        db=db, sucursal_id=sucursal_id, page=page,
        items_per_page=items_per_page, disponible_venta=disponible_venta,
    )


# ─── GET /productos/{id} ──────────────────────────────────────────────────────

@router.get("/{producto_id}", response_model=ProductoRead, summary="Obtener producto")
def read_producto(
    producto_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    producto = get_producto(db, producto_id)
    if not producto:
        raise NotFoundException("Producto no encontrado")

    verify_empresa_access(current_user, UUID(str(producto["empresa_id"])))  # 🔒 su empresa
    return producto


# ─── POST /productos/ ─────────────────────────────────────────────────────────

@router.post(
    "/",
    response_model=ProductoRead,
    status_code=status.HTTP_201_CREATED,
    summary="Crear producto",
)
@limiter.limit("60/hour", key_func=get_user_id_from_token)  # 🚦 catálogo puede ser grande
def write_producto(
    request: Request,
    data: ProductoCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    verify_empresa_access(current_user, data.empresa_id)  # 🔒 su empresa

    # Validar que la categoría existe y pertenece a la misma empresa
    categoria = get_categoria(db, data.categoria_id)
    if not categoria:
        raise NotFoundException("Categoría no encontrada")
    if str(categoria["empresa_id"]) != str(data.empresa_id):
        raise BadRequestException("La categoría debe pertenecer a la misma empresa")

    # Unicidad de código interno
    if data.codigo_interno and producto_codigo_exists(db, data.empresa_id, data.codigo_interno):
        raise DuplicateValueException(f"El código '{data.codigo_interno}' ya existe en esta empresa")

    internal = ProductoCreateInternal(
        **data.model_dump(),
        created_by=UUID(str(current_user["id"])),
    )
    nuevo = create_producto(db, internal)

    logger.info(
        "Producto creado | id={id} | nombre={nombre} | empresa={empresa} | por={admin}",
        id=nuevo.get("id"),
        nombre=nuevo.get("nombre"),
        empresa=str(data.empresa_id),
        admin=current_user.get("email"),
    )
    return nuevo


# ─── PATCH /productos/{id} ────────────────────────────────────────────────────

@router.patch(
    "/{producto_id}",
    response_model=ProductoRead,
    summary="Actualizar producto",
)
@limiter.limit("60/hour", key_func=get_user_id_from_token)  # 🚦
def patch_producto(
    request: Request,
    producto_id: UUID,
    values: ProductoUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    producto = get_producto(db, producto_id)
    if not producto:
        raise NotFoundException("Producto no encontrado")

    verify_empresa_access(current_user, UUID(str(producto["empresa_id"])))  # 🔒 su empresa

    # Validar categoría si se está cambiando
    if values.categoria_id:
        categoria = get_categoria(db, values.categoria_id)
        if not categoria:
            raise NotFoundException("Categoría no encontrada")
        if str(categoria["empresa_id"]) != str(producto["empresa_id"]):
            raise BadRequestException("La categoría debe pertenecer a la misma empresa")

    # Unicidad de código interno si se cambia
    if values.codigo_interno and values.codigo_interno.upper() != producto.get("codigo_interno"):
        empresa_id = UUID(str(producto["empresa_id"]))
        if producto_codigo_exists(db, empresa_id, values.codigo_interno, exclude_id=producto_id):
            raise DuplicateValueException(f"El código '{values.codigo_interno}' ya existe en esta empresa")

    internal = ProductoUpdateInternal(
        **values.model_dump(exclude_unset=True),
        updated_at=datetime.now(UTC),
        updated_by=UUID(str(current_user["id"])),
    )
    updated = update_producto(db, producto_id, internal)
    if not updated:
        raise NotFoundException("No se pudo actualizar el producto")

    logger.info(
        "Producto actualizado | id={id} | por={admin}",
        id=str(producto_id),
        admin=current_user.get("email"),
    )
    return updated


# ─── DELETE /productos/{id} ── soft delete ────────────────────────────────────

@router.delete(
    "/{producto_id}",
    status_code=status.HTTP_200_OK,
    summary="Desactivar producto (soft delete)",
    description="Desactiva el producto y lo deshabilita en todas sus sucursales.",
)
@limiter.limit("20/hour", key_func=get_user_id_from_token)  # 🚦
def delete_producto(
    request: Request,
    producto_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    producto = get_producto(db, producto_id)
    if not producto:
        raise NotFoundException("Producto no encontrado")

    verify_empresa_access(current_user, UUID(str(producto["empresa_id"])))  # 🔒 su empresa

    updated_by = UUID(str(current_user["id"]))
    sucursales_afectadas = deshabilitar_producto_en_sucursales(db, producto_id)
    soft_delete_producto(db, producto_id, updated_by)

    logger.warning(
        "Producto desactivado [soft] | id={id} | nombre={nombre} | sucursales={suc} | por={admin}",
        id=str(producto_id),
        nombre=producto.get("nombre"),
        suc=sucursales_afectadas,
        admin=current_user.get("email"),
    )
    return {
        "message": f"Producto '{producto['nombre']}' desactivado.",
        "sucursales_afectadas": sucursales_afectadas,
    }


# ─── DELETE /productos/{id}/hard ──────────────────────────────────────────────

@router.delete(
    "/{producto_id}/hard",
    status_code=status.HTTP_200_OK,
    summary="Eliminar producto permanentemente",
    description="Borra físicamente el producto y sus registros en sucursales. **Solo super_admin.**",
)
@limiter.limit("10/hour", key_func=get_user_id_from_token)  # 🚦
def hard_delete_producto_endpoint(
    request: Request,
    producto_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],  # 🔒 solo super_admin
) -> dict:
    producto = get_producto(db, producto_id)
    if not producto:
        raise NotFoundException("Producto no encontrado")

    hard_delete_producto(db, producto_id)

    logger.warning(
        "Producto ELIMINADO [hard] | id={id} | nombre={nombre} | por={admin}",
        id=str(producto_id),
        nombre=producto.get("nombre"),
        admin=current_user.get("email"),
    )
    return {"message": f"Producto '{producto['nombre']}' eliminado permanentemente."}


# ─── GET /productos/{id}/sucursales/{sucursal_id} ─────────────────────────────

@router.get(
    "/{producto_id}/sucursales/{sucursal_id}",
    response_model=ProductoSucursalRead,
    summary="Obtener precio y stock de un producto en una sucursal",
)
def read_producto_sucursal(
    producto_id: UUID,
    sucursal_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    producto = get_producto(db, producto_id)
    if not producto:
        raise NotFoundException("Producto no encontrado")

    verify_empresa_access(current_user, UUID(str(producto["empresa_id"])))  # 🔒 su empresa

    ps = get_producto_sucursal(db, producto_id, sucursal_id)
    if not ps:
        raise NotFoundException("El producto no está configurado en esa sucursal")
    return ps


# ─── POST /productos/{id}/sucursales ─────────────────────────────────────────

@router.post(
    "/{producto_id}/sucursales",
    response_model=ProductoSucursalRead,
    status_code=status.HTTP_201_CREATED,
    summary="Configurar producto en una sucursal (precio y stock)",
)
@limiter.limit("60/hour", key_func=get_user_id_from_token)  # 🚦
def write_producto_sucursal(
    request: Request,
    producto_id: UUID,
    data: ProductoSucursalCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    producto = get_producto(db, producto_id)
    if not producto:
        raise NotFoundException("Producto no encontrado")

    verify_empresa_access(current_user, UUID(str(producto["empresa_id"])))  # 🔒 su empresa

    sucursal = get_sucursal(db, data.sucursal_id)
    if not sucursal:
        raise NotFoundException("Sucursal no encontrada")
    if str(sucursal["empresa_id"]) != str(producto["empresa_id"]):
        raise BadRequestException("La sucursal debe pertenecer a la misma empresa que el producto")

    if producto_sucursal_exists(db, producto_id, data.sucursal_id):
        raise DuplicateValueException("El producto ya está configurado en esa sucursal")

    # Forzar el producto_id del path — ignorar lo que venga en el body
    data_dict = data.model_dump()
    data_dict["producto_id"] = producto_id
    nuevo = create_producto_sucursal(db, ProductoSucursalCreate(**data_dict))

    logger.info(
        "Producto en sucursal creado | producto={prod} | sucursal={suc} | precio={precio} | por={admin}",
        prod=str(producto_id),
        suc=str(data.sucursal_id),
        precio=str(data.precio_venta),
        admin=current_user.get("email"),
    )
    return nuevo


# ─── PATCH /productos/sucursales/{ps_id} ──────────────────────────────────────

@router.patch(
    "/sucursales/{ps_id}",
    response_model=ProductoSucursalRead,
    summary="Actualizar precio, stock o configuración de un producto en una sucursal",
)
@limiter.limit("60/hour", key_func=get_user_id_from_token)  # 🚦
def patch_producto_sucursal(
    request: Request,
    ps_id: UUID,
    values: ProductoSucursalUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    ps = get_producto_sucursal_by_id(db, ps_id)
    if not ps:
        raise NotFoundException("Configuración de producto en sucursal no encontrada")

    producto = get_producto(db, UUID(str(ps["producto_id"])))
    if producto:
        verify_empresa_access(current_user, UUID(str(producto["empresa_id"])))  # 🔒 su empresa

    internal = ProductoSucursalUpdateInternal(
        **values.model_dump(exclude_unset=True),
        updated_at=datetime.now(UTC),
    )
    updated = update_producto_sucursal(db, ps_id, internal)
    if not updated:
        raise NotFoundException("No se pudo actualizar")

    logger.info(
        "Producto-sucursal actualizado | id={id} | por={admin}",
        id=str(ps_id),
        admin=current_user.get("email"),
    )
    return updated


# ─── DELETE /productos/sucursales/{ps_id} ─────────────────────────────────────

@router.delete(
    "/sucursales/{ps_id}",
    status_code=status.HTTP_200_OK,
    summary="Eliminar configuración de producto en sucursal",
)
@limiter.limit("20/hour", key_func=get_user_id_from_token)  # 🚦
def delete_producto_sucursal_endpoint(
    request: Request,
    ps_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    ps = get_producto_sucursal_by_id(db, ps_id)
    if not ps:
        raise NotFoundException("Configuración no encontrada")

    producto = get_producto(db, UUID(str(ps["producto_id"])))
    if producto:
        verify_empresa_access(current_user, UUID(str(producto["empresa_id"])))  # 🔒 su empresa

    delete_producto_sucursal(db, ps_id)

    logger.warning(
        "Producto-sucursal eliminado | id={id} | por={admin}",
        id=str(ps_id),
        admin=current_user.get("email"),
    )
    return {"message": "Configuración de producto en sucursal eliminada"}