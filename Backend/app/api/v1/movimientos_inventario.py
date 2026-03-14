"""
Router de Movimientos de Inventario — solo lógica HTTP.

Flujo de estados:
  borrador → completado  (actualiza stock en productos_sucursales)
  borrador → cancelado   (sin efecto en stock)
  completado → cancelado (stock NO se revierte — requiere movimiento inverso)

Seguridad:
  GET    /movimientos-inventario/              → admin_empresa o super_admin
  GET    /movimientos-inventario/{id}          → admin_empresa o super_admin
  GET    /movimientos-inventario/{id}/detalle  → admin_empresa o super_admin
  POST   /movimientos-inventario/              → admin_empresa o super_admin
  PATCH  /movimientos-inventario/{id}          → admin_empresa o super_admin (solo borrador)
  PATCH  /movimientos-inventario/{id}/estado   → admin_empresa o super_admin
  DELETE /movimientos-inventario/{id}/hard     → solo super_admin (solo borrador/cancelado)

  --- Ítems ---
  POST   /movimientos-inventario/{id}/items          → admin_empresa (solo borrador)
  DELETE /movimientos-inventario/{id}/items/{item_id} → admin_empresa (solo borrador)
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
    verify_empresa_access,
)
from ...crud.crud_movimientos_inventario import (
    add_detalle_item,
    cancelar_movimiento,
    completar_movimiento,
    create_movimiento,
    delete_detalle_item,
    get_detalle_item,
    get_movimiento,
    get_movimiento_con_detalle,
    get_movimientos,
    hard_delete_movimiento,
    numero_movimiento_exists,
    update_movimiento,
)
from ...crud.crud_sucursales import get_sucursal
from ...database import get_supabase
from ...schemas.movimiento_inventario import (
    DetalleMovimientoCreate,
    DetalleMovimientoRead,
    MovimientoEstadoUpdate,
    MovimientoInventarioCreate,
    MovimientoInventarioRead,
    MovimientoInventarioReadDetalle,
    MovimientoInventarioUpdate,
)
from datetime import datetime

router = APIRouter(prefix="/movimientos-inventario", tags=["Movimientos de Inventario"])


def _verificar_borrador(movimiento: dict) -> None:
    if movimiento["estado"] != "borrador":
        raise BadRequestException(
            f"El movimiento está en estado '{movimiento['estado']}'. "
            "Solo se puede modificar en estado 'borrador'."
        )


# ─── GET /movimientos-inventario/ ─────────────────────────────────────────────

@router.get(
    "/",
    response_model=PaginatedResponse[MovimientoInventarioRead],
    summary="Listar movimientos de inventario",
)
def read_movimientos(
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 20,
    order_by: str = "fecha_movimiento",
    order_desc: bool = True,
    sucursal_id: UUID | None = None,
    tipo_movimiento: str | None = None,
    estado: str | None = None,
    fecha_desde: datetime | None = None,
    fecha_hasta: datetime | None = None,
    empresa_id: UUID | None = None,
) -> dict:
    if current_user["rol_global"] == "super_admin":
        if not empresa_id:
            raise BadRequestException("super_admin debe especificar empresa_id como query param")
        target = empresa_id
    else:
        target = UUID(str(current_user["empresa_id"]))

    return get_movimientos(
        db=db, empresa_id=target, page=page, items_per_page=items_per_page,
        order_by=order_by, order_desc=order_desc, sucursal_id=sucursal_id,
        tipo_movimiento=tipo_movimiento, estado=estado,
        fecha_desde=fecha_desde, fecha_hasta=fecha_hasta,
    )


# ─── GET /movimientos-inventario/{id} ─────────────────────────────────────────

@router.get("/{movimiento_id}", response_model=MovimientoInventarioRead, summary="Obtener movimiento")
def read_movimiento(
    movimiento_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    movimiento = get_movimiento(db, movimiento_id)
    if not movimiento:
        raise NotFoundException("Movimiento no encontrado")
    verify_empresa_access(current_user, UUID(str(movimiento["empresa_id"])))
    return movimiento


# ─── GET /movimientos-inventario/{id}/detalle ─────────────────────────────────

@router.get(
    "/{movimiento_id}/detalle",
    response_model=MovimientoInventarioReadDetalle,
    summary="Obtener movimiento con ítems",
)
def read_movimiento_detalle(
    movimiento_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    movimiento = get_movimiento_con_detalle(db, movimiento_id)
    if not movimiento:
        raise NotFoundException("Movimiento no encontrado")
    verify_empresa_access(current_user, UUID(str(movimiento["empresa_id"])))
    return movimiento


# ─── POST /movimientos-inventario/ ────────────────────────────────────────────

@router.post(
    "/",
    response_model=MovimientoInventarioRead,
    status_code=status.HTTP_201_CREATED,
    summary="Crear movimiento de inventario",
    description="Crea el movimiento en estado 'borrador'. Completarlo actualiza el stock.",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)
def write_movimiento(
    request: Request,
    data: MovimientoInventarioCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    verify_empresa_access(current_user, data.empresa_id)

    sucursal = get_sucursal(db, data.sucursal_id)
    if not sucursal:
        raise NotFoundException("Sucursal no encontrada")
    if str(sucursal["empresa_id"]) != str(data.empresa_id):
        raise BadRequestException("La sucursal no pertenece a esta empresa")

    # Validar sucursales de transferencia si aplica
    if data.sucursal_origen_id:
        origen = get_sucursal(db, data.sucursal_origen_id)
        if not origen or str(origen["empresa_id"]) != str(data.empresa_id):
            raise BadRequestException("La sucursal origen no existe o no pertenece a esta empresa")
    if data.sucursal_destino_id:
        destino = get_sucursal(db, data.sucursal_destino_id)
        if not destino or str(destino["empresa_id"]) != str(data.empresa_id):
            raise BadRequestException("La sucursal destino no existe o no pertenece a esta empresa")

    if numero_movimiento_exists(db, data.empresa_id, data.numero_movimiento):
        raise DuplicateValueException(
            f"El número '{data.numero_movimiento}' ya existe en esta empresa"
        )

    nuevo = create_movimiento(
        db, data,
        usuario_responsable=UUID(str(current_user["id"])),
    )

    logger.info(
        "Movimiento creado | id={id} | tipo={tipo} | numero={num} | empresa={emp} | por={admin}",
        id=nuevo.get("id"),
        tipo=nuevo.get("tipo_movimiento"),
        num=nuevo.get("numero_movimiento"),
        emp=str(data.empresa_id),
        admin=current_user.get("email"),
    )
    return nuevo


# ─── PATCH /movimientos-inventario/{id} ───────────────────────────────────────

@router.patch(
    "/{movimiento_id}",
    response_model=MovimientoInventarioRead,
    summary="Actualizar movimiento",
    description="Solo editable en estado 'borrador'. Permite actualizar motivo, factura y documento.",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)
def patch_movimiento(
    request: Request,
    movimiento_id: UUID,
    values: MovimientoInventarioUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    movimiento = get_movimiento(db, movimiento_id)
    if not movimiento:
        raise NotFoundException("Movimiento no encontrado")
    verify_empresa_access(current_user, UUID(str(movimiento["empresa_id"])))
    _verificar_borrador(movimiento)

    updated = update_movimiento(db, movimiento_id, values)
    if not updated:
        raise NotFoundException("No se pudo actualizar el movimiento")

    logger.info(
        "Movimiento actualizado | id={id} | por={admin}",
        id=str(movimiento_id),
        admin=current_user.get("email"),
    )
    return updated


# ─── PATCH /movimientos-inventario/{id}/estado ────────────────────────────────

@router.patch(
    "/{movimiento_id}/estado",
    response_model=MovimientoInventarioRead,
    summary="Completar o cancelar movimiento",
    description=(
        "**completado**: actualiza el stock en productos_sucursales. "
        "**cancelado**: no revierte el stock si ya estaba completado."
    ),
)
@limiter.limit("20/hour", key_func=get_user_id_from_token)
def patch_estado_movimiento(
    request: Request,
    movimiento_id: UUID,
    values: MovimientoEstadoUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    movimiento = get_movimiento(db, movimiento_id)
    if not movimiento:
        raise NotFoundException("Movimiento no encontrado")
    verify_empresa_access(current_user, UUID(str(movimiento["empresa_id"])))

    estado_actual = movimiento["estado"]

    if estado_actual == "completado" and values.estado == "completado":
        raise BadRequestException("El movimiento ya está completado")
    if estado_actual == "cancelado":
        raise BadRequestException("El movimiento ya está cancelado — estado final")

    if values.estado == "completado":
        updated = completar_movimiento(db, movimiento_id)
    else:
        updated = cancelar_movimiento(db, movimiento_id)

    logger.warning(
        "Estado de movimiento cambiado | id={id} | {anterior} → {nuevo} | por={admin}",
        id=str(movimiento_id),
        anterior=estado_actual,
        nuevo=values.estado,
        admin=current_user.get("email"),
    )
    return updated


# ─── DELETE /movimientos-inventario/{id}/hard ─────────────────────────────────

@router.delete(
    "/{movimiento_id}/hard",
    status_code=status.HTTP_200_OK,
    summary="Eliminar movimiento permanentemente",
    description="**Solo super_admin.** Solo permitido en estado 'borrador' o 'cancelado'.",
)
@limiter.limit("5/hour", key_func=get_user_id_from_token)
def hard_delete_movimiento_endpoint(
    request: Request,
    movimiento_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],  # 🔒 solo super_admin
) -> dict:
    movimiento = get_movimiento(db, movimiento_id)
    if not movimiento:
        raise NotFoundException("Movimiento no encontrado")
    if movimiento["estado"] not in ("borrador", "cancelado"):
        raise BadRequestException(
            f"Solo se pueden eliminar movimientos en estado 'borrador' o 'cancelado'. "
            f"Estado actual: '{movimiento['estado']}'"
        )

    hard_delete_movimiento(db, movimiento_id)

    logger.warning(
        "Movimiento ELIMINADO [hard] | id={id} | numero={num} | por={admin}",
        id=str(movimiento_id),
        num=movimiento.get("numero_movimiento"),
        admin=current_user.get("email"),
    )
    return {"message": f"Movimiento '{movimiento['numero_movimiento']}' eliminado permanentemente"}


# ─── POST /movimientos-inventario/{id}/items ──────────────────────────────────

@router.post(
    "/{movimiento_id}/items",
    response_model=DetalleMovimientoRead,
    status_code=status.HTTP_201_CREATED,
    summary="Agregar ítem al movimiento",
    description="Solo en estado 'borrador'. El total_costo se recalcula automáticamente.",
)
@limiter.limit("60/hour", key_func=get_user_id_from_token)
def add_item(
    request: Request,
    movimiento_id: UUID,
    data: DetalleMovimientoCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    movimiento = get_movimiento(db, movimiento_id)
    if not movimiento:
        raise NotFoundException("Movimiento no encontrado")
    verify_empresa_access(current_user, UUID(str(movimiento["empresa_id"])))
    _verificar_borrador(movimiento)

    item = add_detalle_item(db, movimiento_id, data)

    logger.info(
        "Ítem agregado a movimiento | movimiento={mov} | por={admin}",
        mov=str(movimiento_id),
        admin=current_user.get("email"),
    )
    return item


# ─── DELETE /movimientos-inventario/{id}/items/{item_id} ──────────────────────

@router.delete(
    "/{movimiento_id}/items/{item_id}",
    status_code=status.HTTP_200_OK,
    summary="Eliminar ítem del movimiento",
    description="Solo en estado 'borrador'. El total_costo se recalcula automáticamente.",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)
def delete_item(
    request: Request,
    movimiento_id: UUID,
    item_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    movimiento = get_movimiento(db, movimiento_id)
    if not movimiento:
        raise NotFoundException("Movimiento no encontrado")
    verify_empresa_access(current_user, UUID(str(movimiento["empresa_id"])))
    _verificar_borrador(movimiento)

    item = get_detalle_item(db, item_id)
    if not item:
        raise NotFoundException("Ítem no encontrado")
    if str(item["movimiento_id"]) != str(movimiento_id):
        raise NotFoundException("El ítem no pertenece a este movimiento")

    delete_detalle_item(db, item_id, movimiento_id)

    logger.info(
        "Ítem eliminado de movimiento | movimiento={mov} | item={item} | por={admin}",
        mov=str(movimiento_id),
        item=str(item_id),
        admin=current_user.get("email"),
    )
    return {"message": "Ítem eliminado. Total costo recalculado."}