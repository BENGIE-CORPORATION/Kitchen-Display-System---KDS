"""
Router de Recetas — solo lógica HTTP.
Una receta define los ingredientes (materias primas) de un producto.

Seguridad:
  GET    /productos/{id}/receta              → autenticado + misma empresa
  GET    /productos/{id}/receta/{receta_id}  → autenticado + misma empresa
  POST   /productos/{id}/receta              → admin_empresa o super_admin
  PATCH  /productos/{id}/receta/{receta_id}  → admin_empresa o super_admin
  DELETE /productos/{id}/receta/{receta_id}  → admin_empresa o super_admin
"""

from decimal import Decimal
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
from ...crud.crud_materias_primas import get_materia_prima
from ...crud.crud_productos import get_producto
from ...crud.crud_recetas import (
    create_ingrediente,
    delete_ingrediente,
    get_ingrediente,
    get_receta_por_producto,
    receta_ingrediente_exists,
    update_ingrediente,
)
from ...database import get_supabase
from ...schemas.receta import (
    RecetaCreate,
    RecetaReadDetalle,
    RecetaUpdate,
)

router = APIRouter(tags=["Recetas"])


def _get_producto_verificado(db: Client, producto_id: UUID, current_user: dict) -> dict:
    producto = get_producto(db, producto_id)
    if not producto:
        raise NotFoundException("Producto no encontrado")
    verify_empresa_access(current_user, UUID(str(producto["empresa_id"])))
    return producto


def _verificar_ingrediente_pertenece(ingrediente: dict, producto_id: UUID) -> None:
    if str(ingrediente["producto_id"]) != str(producto_id):
        raise NotFoundException("El ingrediente no pertenece a la receta de este producto")


# ─── GET /productos/{id}/receta ───────────────────────────────────────────────

@router.get(
    "/productos/{producto_id}/receta",
    response_model=list[RecetaReadDetalle],
    summary="Obtener receta de un producto",
    description="Lista todos los ingredientes (materias primas) necesarios para producir el producto.",
)
def read_receta(
    producto_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> list:
    _get_producto_verificado(db, producto_id, current_user)
    return get_receta_por_producto(db, producto_id)


# ─── GET /productos/{id}/receta/{receta_id} ───────────────────────────────────

@router.get(
    "/productos/{producto_id}/receta/{receta_id}",
    response_model=RecetaReadDetalle,
    summary="Obtener ingrediente de una receta",
)
def read_ingrediente(
    producto_id: UUID,
    receta_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    _get_producto_verificado(db, producto_id, current_user)
    ingrediente = get_ingrediente(db, receta_id)
    if not ingrediente:
        raise NotFoundException("Ingrediente no encontrado")
    _verificar_ingrediente_pertenece(ingrediente, producto_id)
    return ingrediente


# ─── POST /productos/{id}/receta ──────────────────────────────────────────────

@router.post(
    "/productos/{producto_id}/receta",
    response_model=RecetaReadDetalle,
    status_code=status.HTTP_201_CREATED,
    summary="Agregar ingrediente a la receta",
)
@limiter.limit("60/hour", key_func=get_user_id_from_token)
def write_ingrediente(
    request: Request,
    producto_id: UUID,
    data: RecetaCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    producto = _get_producto_verificado(db, producto_id, current_user)

    # Validar que la materia prima existe y es de la misma empresa
    mp = get_materia_prima(db, data.materia_prima_id)
    if not mp:
        raise NotFoundException("Materia prima no encontrada")
    if str(mp["empresa_id"]) != str(producto["empresa_id"]):
        raise BadRequestException("La materia prima debe pertenecer a la misma empresa")

    if receta_ingrediente_exists(db, producto_id, data.materia_prima_id):
        raise DuplicateValueException(
            f"La materia prima '{mp['nombre']}' ya está en la receta de este producto"
        )

    nuevo = create_ingrediente(db, producto_id, data, UUID(str(current_user["id"])))

    logger.info(
        "Ingrediente agregado | producto={prod} | mp={mp} | cantidad={qty} | por={admin}",
        prod=str(producto_id),
        mp=mp.get("nombre"),
        qty=str(data.cantidad),
        admin=current_user.get("email"),
    )
    return nuevo


# ─── PATCH /productos/{id}/receta/{receta_id} ─────────────────────────────────

@router.patch(
    "/productos/{producto_id}/receta/{receta_id}",
    response_model=RecetaReadDetalle,
    summary="Actualizar ingrediente de la receta",
)
@limiter.limit("60/hour", key_func=get_user_id_from_token)
def patch_ingrediente(
    request: Request,
    producto_id: UUID,
    receta_id: UUID,
    values: RecetaUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    _get_producto_verificado(db, producto_id, current_user)

    ingrediente = get_ingrediente(db, receta_id)
    if not ingrediente:
        raise NotFoundException("Ingrediente no encontrado")
    _verificar_ingrediente_pertenece(ingrediente, producto_id)

    updated = update_ingrediente(db, receta_id, values)
    if not updated:
        raise NotFoundException("No se pudo actualizar el ingrediente")

    logger.info(
        "Ingrediente actualizado | receta={id} | producto={prod} | por={admin}",
        id=str(receta_id),
        prod=str(producto_id),
        admin=current_user.get("email"),
    )
    return updated


# ─── DELETE /productos/{id}/receta/{receta_id} ────────────────────────────────

@router.delete(
    "/productos/{producto_id}/receta/{receta_id}",
    status_code=status.HTTP_200_OK,
    summary="Eliminar ingrediente de la receta",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)
def delete_ingrediente_endpoint(
    request: Request,
    producto_id: UUID,
    receta_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    _get_producto_verificado(db, producto_id, current_user)

    ingrediente = get_ingrediente(db, receta_id)
    if not ingrediente:
        raise NotFoundException("Ingrediente no encontrado")
    _verificar_ingrediente_pertenece(ingrediente, producto_id)

    delete_ingrediente(db, receta_id)

    logger.warning(
        "Ingrediente eliminado | receta={id} | producto={prod} | por={admin}",
        id=str(receta_id),
        prod=str(producto_id),
        admin=current_user.get("email"),
    )
    return {"message": "Ingrediente eliminado de la receta"}