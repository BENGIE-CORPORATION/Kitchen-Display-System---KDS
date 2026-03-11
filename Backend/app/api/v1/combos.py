"""
Router de Combos — solo lógica HTTP.
Toda la lógica de base de datos vive en app/crud/crud_combos.py

Un combo es un producto de tipo 'combo' que agrupa otros productos como componentes.
Cada componente tiene cantidad y flag de opcional/requerido.
No tienen soft delete — son definición estructural del producto.

Seguridad:
  GET    /productos/{id}/combos              → autenticado + misma empresa
  GET    /productos/{id}/combos/{c_id}       → autenticado + misma empresa
  POST   /productos/{id}/combos              → admin_empresa o super_admin
  PATCH  /productos/{id}/combos/{c_id}       → admin_empresa o super_admin
  DELETE /productos/{id}/combos/{c_id}       → admin_empresa o super_admin
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
from ...crud.crud_combos import (
    componente_exists,
    create_componente,
    delete_componente,
    get_componente,
    get_componentes_por_combo,
    update_componente,
)
from ...crud.crud_productos import get_producto
from ...database import get_supabase
from ...schemas.combo import (
    ComboCreate,
    ComboReadDetalle,
    ComboUpdate,
)

router = APIRouter(tags=["Combos"])


def _get_combo_verificado(db: Client, producto_id: UUID, current_user: dict) -> dict:
    """Obtiene el producto, verifica que sea tipo 'combo' y que el usuario tenga acceso."""
    producto = get_producto(db, producto_id)
    if not producto:
        raise NotFoundException("Producto no encontrado")
    if producto.get("tipo_producto") != "combo":
        raise BadRequestException(
            f"El producto '{producto['nombre']}' no es de tipo 'combo'"
        )
    verify_empresa_access(current_user, UUID(str(producto["empresa_id"])))
    return producto


def _verificar_componente_pertenece(componente: dict, producto_id: UUID) -> None:
    if str(componente["producto_id"]) != str(producto_id):
        raise NotFoundException("El componente no pertenece a este combo")


# ─── GET /productos/{id}/combos ───────────────────────────────────────────────

@router.get(
    "/productos/{producto_id}/combos",
    response_model=list[ComboReadDetalle],
    summary="Listar componentes de un combo",
    description="Retorna todos los productos que componen el combo, con sus datos básicos.",
)
def read_combos(
    producto_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> list:
    _get_combo_verificado(db, producto_id, current_user)
    return get_componentes_por_combo(db, producto_id)


# ─── GET /productos/{id}/combos/{c_id} ───────────────────────────────────────

@router.get(
    "/productos/{producto_id}/combos/{componente_id}",
    response_model=ComboReadDetalle,
    summary="Obtener componente de un combo",
)
def read_combo(
    producto_id: UUID,
    componente_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    _get_combo_verificado(db, producto_id, current_user)

    componente = get_componente(db, componente_id)
    if not componente:
        raise NotFoundException("Componente no encontrado")
    _verificar_componente_pertenece(componente, producto_id)
    return componente


# ─── POST /productos/{id}/combos ──────────────────────────────────────────────

@router.post(
    "/productos/{producto_id}/combos",
    response_model=ComboReadDetalle,
    status_code=status.HTTP_201_CREATED,
    summary="Agregar componente al combo",
    description="Agrega un producto como componente del combo con su cantidad y flag opcional.",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)  # 🚦
def write_combo(
    request: Request,
    producto_id: UUID,
    data: ComboCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    producto_combo = _get_combo_verificado(db, producto_id, current_user)

    # El componente no puede ser el mismo producto combo
    if str(data.producto_componente_id) == str(producto_id):
        raise BadRequestException("Un combo no puede ser componente de sí mismo")

    # Verificar que el componente existe y es de la misma empresa
    componente_producto = get_producto(db, data.producto_componente_id)
    if not componente_producto:
        raise NotFoundException("El producto componente no existe")
    if str(componente_producto["empresa_id"]) != str(producto_combo["empresa_id"]):
        raise BadRequestException("El componente debe pertenecer a la misma empresa")

    # Un combo no puede tener otro combo como componente (evita recursión)
    if componente_producto.get("tipo_producto") == "combo":
        raise BadRequestException("Un combo no puede contener otro combo como componente")

    # Verificar que no esté ya registrado
    if componente_exists(db, producto_id, data.producto_componente_id):
        raise DuplicateValueException(
            f"El producto '{componente_producto['nombre']}' ya es componente de este combo"
        )

    nuevo = create_componente(db, producto_id, data)

    logger.info(
        "Componente agregado al combo | combo={combo} | componente={comp} | cantidad={qty} | por={admin}",
        combo=str(producto_id),
        comp=str(data.producto_componente_id),
        qty=str(data.cantidad),
        admin=current_user.get("email"),
    )
    return nuevo


# ─── PATCH /productos/{id}/combos/{c_id} ─────────────────────────────────────

@router.patch(
    "/productos/{producto_id}/combos/{componente_id}",
    response_model=ComboReadDetalle,
    summary="Actualizar componente de un combo",
    description="Modifica la cantidad o el flag opcional de un componente.",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)  # 🚦
def patch_combo(
    request: Request,
    producto_id: UUID,
    componente_id: UUID,
    values: ComboUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    _get_combo_verificado(db, producto_id, current_user)

    componente = get_componente(db, componente_id)
    if not componente:
        raise NotFoundException("Componente no encontrado")
    _verificar_componente_pertenece(componente, producto_id)

    updated = update_componente(db, componente_id, values)
    if not updated:
        raise NotFoundException("No se pudo actualizar el componente")

    logger.info(
        "Componente actualizado | id={id} | combo={combo} | por={admin}",
        id=str(componente_id),
        combo=str(producto_id),
        admin=current_user.get("email"),
    )
    return updated


# ─── DELETE /productos/{id}/combos/{c_id} ────────────────────────────────────

@router.delete(
    "/productos/{producto_id}/combos/{componente_id}",
    status_code=status.HTTP_200_OK,
    summary="Eliminar componente de un combo",
)
@limiter.limit("20/hour", key_func=get_user_id_from_token)  # 🚦
def delete_combo_endpoint(
    request: Request,
    producto_id: UUID,
    componente_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    _get_combo_verificado(db, producto_id, current_user)

    componente = get_componente(db, componente_id)
    if not componente:
        raise NotFoundException("Componente no encontrado")
    _verificar_componente_pertenece(componente, producto_id)

    delete_componente(db, componente_id)

    logger.warning(
        "Componente eliminado del combo | id={id} | combo={combo} | por={admin}",
        id=str(componente_id),
        combo=str(producto_id),
        admin=current_user.get("email"),
    )
    return {"message": "Componente eliminado del combo"}