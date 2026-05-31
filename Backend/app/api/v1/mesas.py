"""
Router de Mesas — solo lógica HTTP.

Reglas de negocio:
  - El número de mesa es único por sucursal.
  - Al crear, el estado inicia en 'libre'.
  - Cualquier empleado autenticado de la sucursal puede cambiar el estado.
  - Solo admin puede crear, editar datos o eliminar mesas.
  - El endpoint /pedido-activo retorna el pedido no terminal más reciente de la mesa.

Seguridad:
  GET    /mesas/                    → autenticado + acceso a la sucursal
  GET    /mesas/{id}                → autenticado + misma empresa
  GET    /mesas/{id}/pedido-activo  → autenticado + misma empresa
  POST   /mesas/                    → admin_empresa o super_admin
  PATCH  /mesas/{id}                → admin_empresa o super_admin
  PATCH  /mesas/{id}/estado         → autenticado (cualquier empleado de la empresa)
  DELETE /mesas/{id}                → admin_empresa o super_admin [soft]
  DELETE /mesas/{id}/hard           → solo super_admin
"""

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
from ...crud.crud_mesas import (
    create_mesa,
    get_mesa,
    get_mesa_raw,
    get_mesas,
    get_pedido_activo_mesa,
    hard_delete_mesa,
    mesa_numero_exists,
    soft_delete_mesa,
    update_estado_mesa,
    update_mesa,
)
from ...database import get_supabase
from ...schemas.mesa import MesaCreate, MesaEstadoUpdate, MesaRead, MesaUpdate

router = APIRouter(prefix="/mesas", tags=["Mesas"])


def _get_mesa_verificada(db: Client, mesa_id: UUID, current_user: dict) -> dict:
    mesa = get_mesa(db, mesa_id)
    if not mesa:
        raise NotFoundException("Mesa no encontrada")
    verify_empresa_access(current_user, UUID(str(mesa["empresa_id"])))
    return mesa


# ─── GET /mesas/ ──────────────────────────────────────────────────────────────

@router.get("/", response_model=PaginatedResponse[MesaRead], summary="Listar mesas")
def read_mesas(
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],
    sucursal_id: UUID,
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 50,
    order_by: str = "numero",
    order_desc: bool = False,
    estado: str | None = None,
    zona: str | None = None,
) -> dict:
    verify_sucursal_access(db, current_user, sucursal_id)
    return get_mesas(
        db=db, sucursal_id=sucursal_id, page=page, items_per_page=items_per_page,
        order_by=order_by, order_desc=order_desc, estado=estado, zona=zona,
    )


# ─── GET /mesas/{id} ──────────────────────────────────────────────────────────

@router.get("/{mesa_id}", response_model=MesaRead, summary="Obtener mesa")
def read_mesa(
    mesa_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],
) -> dict:
    return _get_mesa_verificada(db, mesa_id, current_user)


# ─── GET /mesas/{id}/pedido-activo ────────────────────────────────────────────

@router.get(
    "/{mesa_id}/pedido-activo",
    summary="Pedido activo de la mesa",
    description="Retorna el pedido en curso (no facturado ni cancelado) más reciente de la mesa.",
)
def read_pedido_activo(
    mesa_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],
) -> dict:
    _get_mesa_verificada(db, mesa_id, current_user)
    pedido = get_pedido_activo_mesa(db, mesa_id)
    if not pedido:
        raise NotFoundException("No hay pedido activo en esta mesa")
    return pedido


# ─── POST /mesas/ ─────────────────────────────────────────────────────────────

@router.post(
    "/",
    response_model=MesaRead,
    status_code=status.HTTP_201_CREATED,
    summary="Crear mesa",
)
@limiter.limit("60/hour", key_func=get_user_id_from_token)
def write_mesa(
    request: Request,
    data: MesaCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],
) -> dict:
    verify_empresa_access(current_user, data.empresa_id)

    if mesa_numero_exists(db, data.sucursal_id, data.numero):
        raise DuplicateValueException(
            f"El número de mesa '{data.numero}' ya existe en esta sucursal"
        )

    nueva = create_mesa(db, data, created_by=UUID(str(current_user["id"])))
    logger.info(
        "Mesa creada | id={id} | numero={num} | sucursal={suc} | por={admin}",
        id=nueva.get("id"), num=nueva.get("numero"),
        suc=str(data.sucursal_id), admin=current_user.get("email"),
    )
    return nueva


# ─── PATCH /mesas/{id} ────────────────────────────────────────────────────────

@router.patch("/{mesa_id}", response_model=MesaRead, summary="Actualizar datos de la mesa")
@limiter.limit("60/hour", key_func=get_user_id_from_token)
def patch_mesa(
    request: Request,
    mesa_id: UUID,
    values: MesaUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],
) -> dict:
    _get_mesa_verificada(db, mesa_id, current_user)
    updated = update_mesa(db, mesa_id, values, UUID(str(current_user["id"])))
    if not updated:
        raise NotFoundException("No se pudo actualizar la mesa")
    logger.info("Mesa actualizada | id={id} | por={admin}",
                id=str(mesa_id), admin=current_user.get("email"))
    return updated


# ─── PATCH /mesas/{id}/estado ─────────────────────────────────────────────────

@router.patch(
    "/{mesa_id}/estado",
    response_model=MesaRead,
    summary="Cambiar estado de la mesa",
    description="Cambia el estado entre: libre, ocupada, reservada, fuera_de_servicio.",
)
@limiter.limit("120/hour", key_func=get_user_id_from_token)
def patch_estado_mesa(
    request: Request,
    mesa_id: UUID,
    values: MesaEstadoUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],
) -> dict:
    _get_mesa_verificada(db, mesa_id, current_user)
    updated = update_estado_mesa(db, mesa_id, values, UUID(str(current_user["id"])))
    if not updated:
        raise NotFoundException("No se pudo cambiar el estado de la mesa")
    logger.info(
        "Estado mesa cambiado | id={id} | estado={estado} | por={admin}",
        id=str(mesa_id), estado=values.estado, admin=current_user.get("email"),
    )
    return updated


# ─── DELETE /mesas/{id} ───────────────────────────────────────────────────────

@router.delete(
    "/{mesa_id}",
    status_code=status.HTTP_200_OK,
    summary="Desactivar mesa (soft delete)",
    description="No se puede desactivar una mesa con estado 'ocupada'.",
)
@limiter.limit("20/hour", key_func=get_user_id_from_token)
def delete_mesa(
    request: Request,
    mesa_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],
) -> dict:
    mesa = _get_mesa_verificada(db, mesa_id, current_user)
    if mesa["estado"] == "ocupada":
        raise BadRequestException("No se puede desactivar una mesa con estado 'ocupada'")
    soft_delete_mesa(db, mesa_id, UUID(str(current_user["id"])))
    logger.warning("Mesa desactivada | id={id} | por={admin}",
                   id=str(mesa_id), admin=current_user.get("email"))
    return {"message": f"Mesa '{mesa['numero']}' desactivada"}


# ─── DELETE /mesas/{id}/hard ──────────────────────────────────────────────────

@router.delete(
    "/{mesa_id}/hard",
    status_code=status.HTTP_200_OK,
    summary="Eliminar mesa permanentemente",
    description="**Solo super_admin.** Falla si la mesa tiene pedidos activos.",
)
@limiter.limit("5/hour", key_func=get_user_id_from_token)
def hard_delete_mesa_endpoint(
    request: Request,
    mesa_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],
) -> dict:
    mesa = get_mesa_raw(db, mesa_id)
    if not mesa:
        raise NotFoundException("Mesa no encontrada")

    if get_pedido_activo_mesa(db, mesa_id):
        raise BadRequestException(
            "No se puede eliminar la mesa porque tiene un pedido activo"
        )

    hard_delete_mesa(db, mesa_id)
    logger.warning("Mesa ELIMINADA [hard] | id={id} | numero={num} | por={admin}",
                   id=str(mesa_id), num=mesa.get("numero"),
                   admin=current_user.get("email"))
    return {"message": f"Mesa '{mesa['numero']}' eliminada permanentemente"}
