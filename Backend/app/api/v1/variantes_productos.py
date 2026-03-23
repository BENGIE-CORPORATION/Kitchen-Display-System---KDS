"""
Router de Variantes de Producto — solo lógica HTTP.
Toda la lógica de base de datos vive en app/crud/crud_variantes_producto.py

Las variantes son atributos configurables de un producto (Tamaño, Color, Sabor).
Cada variante tiene un nombre y una lista de opciones posibles.
No tienen soft delete — son metadata pura, no transacciones.

Seguridad:
  GET    /productos/{id}/variantes        → autenticado + misma empresa
  GET    /productos/{id}/variantes/{v_id} → autenticado + misma empresa
  POST   /productos/{id}/variantes        → admin_empresa o super_admin
  PATCH  /productos/{id}/variantes/{v_id} → admin_empresa o super_admin
  DELETE /productos/{id}/variantes/{v_id} → admin_empresa o super_admin
"""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Request, status
from loguru import logger
from supabase import Client

from ...core.exceptions.http_exceptions import (
    BadRequestException,
    DuplicateValueException,
    NotFoundException,
)
from ...core.limiter import get_user_id_from_token, limiter
from ...core.security import (
    get_current_admin,
    get_current_user,
    verify_empresa_access,
)
from ...crud.crud_productos import get_producto
from ...crud.crud_variantes_producto import (
    create_variante,
    delete_variante,
    get_variante,
    get_variantes_por_producto,
    update_variante,
    variante_nombre_exists,
)
from ...database import get_supabase
from ...schemas.variante_producto import (
    VarianteProductoCreate,
    VarianteProductoRead,
    VarianteProductoUpdate,
)

router = APIRouter(tags=["Variantes de Producto"])


def _get_producto_verificado(db: Client, producto_id: UUID, current_user: dict) -> dict:
    """Helper: obtiene el producto y verifica acceso. Lanza excepción si falla."""
    producto = get_producto(db, producto_id)
    if not producto:
        raise NotFoundException("Producto no encontrado")
    verify_empresa_access(current_user, UUID(str(producto["empresa_id"])))
    return producto


# ─── GET /productos/{id}/variantes ───────────────────────────────────────────

@router.get(
    "/productos/{producto_id}/variantes",
    response_model=list[VarianteProductoRead],
    summary="Listar variantes de un producto",
)
def read_variantes(
    producto_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> list:
    _get_producto_verificado(db, producto_id, current_user)
    return get_variantes_por_producto(db, producto_id)


# ─── GET /productos/{id}/variantes/{v_id} ────────────────────────────────────

@router.get(
    "/productos/{producto_id}/variantes/{variante_id}",
    response_model=VarianteProductoRead,
    summary="Obtener variante",
)
def read_variante(
    producto_id: UUID,
    variante_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    _get_producto_verificado(db, producto_id, current_user)

    variante = get_variante(db, variante_id)
    if not variante:
        raise NotFoundException("Variante no encontrada")
    if str(variante["producto_id"]) != str(producto_id):
        raise NotFoundException("Variante no pertenece a este producto")
    return variante


# ─── POST /productos/{id}/variantes ──────────────────────────────────────────

@router.post(
    "/productos/{producto_id}/variantes",
    response_model=VarianteProductoRead,
    status_code=status.HTTP_201_CREATED,
    summary="Agregar variante a un producto",
    description="Agrega un atributo configurable al producto (ej: Tamaño con opciones Pequeño/Grande).",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)  # 🚦
def write_variante(
    request: Request,
    producto_id: UUID,
    data: VarianteProductoCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    producto = _get_producto_verificado(db, producto_id, current_user)

    # Solo productos simples y compuestos tienen variantes
    if producto.get("tipo_producto") not in ("simple", "compuesto"):
        raise BadRequestException(
            f"Los productos de tipo '{producto['tipo_producto']}' no admiten variantes. "
            "Solo 'simple' y 'compuesto'."
        )

    if variante_nombre_exists(db, producto_id, data.nombre):
        raise DuplicateValueException(
            f"Ya existe una variante '{data.nombre}' en este producto"
        )

    nueva = create_variante(db, producto_id, data)

    logger.info(
        "Variante creada | producto={prod} | nombre={nombre} | opciones={n} | por={admin}",
        prod=str(producto_id),
        nombre=data.nombre,
        n=len(data.opciones),
        admin=current_user.get("email"),
    )
    return nueva


# ─── PATCH /productos/{id}/variantes/{v_id} ──────────────────────────────────

@router.patch(
    "/productos/{producto_id}/variantes/{variante_id}",
    response_model=VarianteProductoRead,
    summary="Actualizar variante",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)  # 🚦
def patch_variante(
    request: Request,
    producto_id: UUID,
    variante_id: UUID,
    values: VarianteProductoUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    _get_producto_verificado(db, producto_id, current_user)

    variante = get_variante(db, variante_id)
    if not variante:
        raise NotFoundException("Variante no encontrada")
    if str(variante["producto_id"]) != str(producto_id):
        raise NotFoundException("Variante no pertenece a este producto")

    # Unicidad de nombre si se está cambiando
    if values.nombre and values.nombre != variante.get("nombre"):
        if variante_nombre_exists(db, producto_id, values.nombre, exclude_id=variante_id):
            raise DuplicateValueException(
                f"Ya existe una variante '{values.nombre}' en este producto"
            )

    updated = update_variante(db, variante_id, values)
    if not updated:
        raise NotFoundException("No se pudo actualizar la variante")

    logger.info(
        "Variante actualizada | id={id} | producto={prod} | por={admin}",
        id=str(variante_id),
        prod=str(producto_id),
        admin=current_user.get("email"),
    )
    return updated


# ─── DELETE /productos/{id}/variantes/{v_id} ─────────────────────────────────

@router.delete(
    "/productos/{producto_id}/variantes/{variante_id}",
    status_code=status.HTTP_200_OK,
    summary="Eliminar variante",
    description="Elimina permanentemente la variante y sus opciones.",
)
@limiter.limit("20/hour", key_func=get_user_id_from_token)  # 🚦
def delete_variante_endpoint(
    request: Request,
    producto_id: UUID,
    variante_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    _get_producto_verificado(db, producto_id, current_user)

    variante = get_variante(db, variante_id)
    if not variante:
        raise NotFoundException("Variante no encontrada")
    if str(variante["producto_id"]) != str(producto_id):
        raise NotFoundException("Variante no pertenece a este producto")

    delete_variante(db, variante_id)

    logger.warning(
        "Variante eliminada | id={id} | nombre={nombre} | producto={prod} | por={admin}",
        id=str(variante_id),
        nombre=variante.get("nombre"),
        prod=str(producto_id),
        admin=current_user.get("email"),
    )
    return {"message": f"Variante '{variante['nombre']}' eliminada permanentemente"}