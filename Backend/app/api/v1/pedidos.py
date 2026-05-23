"""
Router de Pedidos — solo lógica HTTP.

Flujo de estados:
  borrador → abierto → en_preparacion → listo → en_entrega → entregado → facturado
  cualquier estado → cancelado (con motivo obligatorio)

Seguridad:
  GET    /pedidos/                          → autenticado (empleado ve su sucursal)
  GET    /pedidos/{id}                      → autenticado + misma empresa
  GET    /pedidos/{id}/detalle              → autenticado + misma empresa
  POST   /pedidos/                          → autenticado
  PATCH  /pedidos/{id}                      → autenticado (solo borrador/abierto)
  PATCH  /pedidos/{id}/estado               → autenticado
  DELETE /pedidos/{id}/hard                 → solo super_admin (borrador/cancelado)

  --- Ítems ---
  POST   /pedidos/{id}/items                → autenticado (solo borrador/abierto)
  PATCH  /pedidos/{id}/items/{item_id}      → autenticado (solo borrador/abierto)
  DELETE /pedidos/{id}/items/{item_id}      → autenticado (cancela el ítem)
"""

from datetime import datetime
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
from ...core.metrics import pedido_estado_cambios, pedidos_creados
from ...core.pagination import PaginatedResponse
from ...core.security import (
    get_current_superadmin,
    get_current_user,
    verify_empresa_access,
)
from ...crud.crud_clientes import actualizar_stats_compra, get_cliente
from ...crud.crud_pedidos import (
    add_detalle_item,
    cancelar_detalle_item,
    cambiar_estado_pedido,
    create_pedido,
    get_detalle_item,
    get_pedido,
    get_pedido_con_detalle,
    get_pedidos,
    hard_delete_pedido,
    numero_pedido_exists,
    update_detalle_item,
    update_pedido,
)
from ...database import get_supabase
from ...models.pedido import TRANSICIONES_PEDIDO
from ...schemas.pedido import (
    DetalleCancelacion,
    DetallePedidoCreate,
    DetallePedidoRead,
    DetallePedidoUpdate,
    PedidoCreate,
    PedidoEstadoUpdate,
    PedidoRead,
    PedidoReadDetalle,
    PedidoUpdate,
)

router = APIRouter(prefix="/pedidos", tags=["Pedidos"])

ESTADOS_EDITABLES = {"borrador", "abierto"}


def _verificar_editable(pedido: dict) -> None:
    if pedido["estado"] not in ESTADOS_EDITABLES:
        raise BadRequestException(
            f"El pedido está '{pedido['estado']}'. "
            f"Solo editable en: {', '.join(ESTADOS_EDITABLES)}."
        )


def _verificar_transicion(estado_actual: str, nuevo_estado: str) -> None:
    permitidos = TRANSICIONES_PEDIDO.get(estado_actual, set())
    if nuevo_estado not in permitidos:
        raise BadRequestException(
            f"No se puede cambiar de '{estado_actual}' a '{nuevo_estado}'. "
            f"Transiciones permitidas: {', '.join(permitidos) or 'ninguna (estado final)'}."
        )


def _get_pedido_verificado(db: Client, pedido_id: UUID, current_user: dict) -> dict:
    pedido = get_pedido(db, pedido_id)
    if not pedido:
        raise NotFoundException("Pedido no encontrado")
    verify_empresa_access(current_user, UUID(str(pedido["empresa_id"])))
    return pedido


# ─── GET /pedidos/ ────────────────────────────────────────────────────────────

@router.get("/", response_model=PaginatedResponse[PedidoRead], summary="Listar pedidos")
def read_pedidos(
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 20,
    order_by: str = "fecha_pedido",
    order_desc: bool = True,
    sucursal_id: UUID | None = None,
    estado: str | None = None,
    estado_pago: str | None = None,
    estado_cocina: str | None = None,
    tipo_pedido: str | None = None,
    cliente_id: UUID | None = None,
    mesa_id: UUID | None = None,
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

    return get_pedidos(
        db=db, empresa_id=target, page=page, items_per_page=items_per_page,
        order_by=order_by, order_desc=order_desc, sucursal_id=sucursal_id,
        estado=estado, estado_pago=estado_pago, estado_cocina=estado_cocina,
        tipo_pedido=tipo_pedido, cliente_id=cliente_id, mesa_id=mesa_id,
        fecha_desde=fecha_desde, fecha_hasta=fecha_hasta,
    )


# ─── GET /pedidos/{id} ────────────────────────────────────────────────────────

@router.get("/{pedido_id}", response_model=PedidoRead, summary="Obtener pedido")
def read_pedido(
    pedido_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    return _get_pedido_verificado(db, pedido_id, current_user)


# ─── GET /pedidos/{id}/detalle ────────────────────────────────────────────────

@router.get("/{pedido_id}/detalle", response_model=PedidoReadDetalle, summary="Obtener pedido con ítems")
def read_pedido_detalle(
    pedido_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    pedido = get_pedido_con_detalle(db, pedido_id)
    if not pedido:
        raise NotFoundException("Pedido no encontrado")
    verify_empresa_access(current_user, UUID(str(pedido["empresa_id"])))
    return pedido


# ─── POST /pedidos/ ───────────────────────────────────────────────────────────

@router.post(
    "/",
    response_model=PedidoRead,
    status_code=status.HTTP_201_CREATED,
    summary="Crear pedido",
    description="Crea el pedido en estado 'borrador' con sus ítems. Totales calculados automáticamente.",
)
@limiter.limit("120/hour", key_func=get_user_id_from_token)
def write_pedido(
    request: Request,
    data: PedidoCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    verify_empresa_access(current_user, data.empresa_id)

    if numero_pedido_exists(db, data.sucursal_id, data.numero_pedido):
        raise DuplicateValueException(
            f"El número de pedido '{data.numero_pedido}' ya existe en esta sucursal"
        )

    if data.cliente_id:
        cliente = get_cliente(db, data.cliente_id)
        if not cliente:
            raise NotFoundException("Cliente no encontrado")
        if str(cliente["empresa_id"]) != str(data.empresa_id):
            raise BadRequestException("El cliente no pertenece a esta empresa")

    nuevo = create_pedido(db, data, created_by=UUID(str(current_user["id"])))

    logger.info(
        "Pedido creado | id={id} | numero={num} | tipo={tipo} | total={total} | por={admin}",
        id=nuevo.get("id"), num=nuevo.get("numero_pedido"),
        tipo=nuevo.get("tipo_pedido"), total=nuevo.get("total"),
        admin=current_user.get("email"),
    )
    pedidos_creados.labels(tipo_pedido=nuevo.get("tipo_pedido", "desconocido")).inc()
    return nuevo


# ─── PATCH /pedidos/{id} ──────────────────────────────────────────────────────

@router.patch("/{pedido_id}", response_model=PedidoRead, summary="Actualizar pedido")
@limiter.limit("60/hour", key_func=get_user_id_from_token)
def patch_pedido(
    request: Request,
    pedido_id: UUID,
    values: PedidoUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    pedido = _get_pedido_verificado(db, pedido_id, current_user)
    _verificar_editable(pedido)

    updated = update_pedido(db, pedido_id, values, UUID(str(current_user["id"])))
    if not updated:
        raise NotFoundException("No se pudo actualizar el pedido")

    logger.info("Pedido actualizado | id={id} | por={admin}",
                id=str(pedido_id), admin=current_user.get("email"))
    return updated


# ─── PATCH /pedidos/{id}/estado ───────────────────────────────────────────────

@router.patch(
    "/{pedido_id}/estado",
    response_model=PedidoRead,
    summary="Cambiar estado del pedido",
    description="Valida la transición de estado según el flujo definido.",
)
@limiter.limit("60/hour", key_func=get_user_id_from_token)
def patch_estado_pedido(
    request: Request,
    pedido_id: UUID,
    values: PedidoEstadoUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    pedido = _get_pedido_verificado(db, pedido_id, current_user)
    _verificar_transicion(pedido["estado"], values.estado)

    updated = cambiar_estado_pedido(db, pedido_id, values, UUID(str(current_user["id"])))
    if not updated:
        raise NotFoundException("No se pudo cambiar el estado")

    # Al facturar, actualizar stats del cliente si existe
    if values.estado == "facturado" and pedido.get("cliente_id"):
        from decimal import Decimal as D
        try:
            actualizar_stats_compra(
                db, UUID(str(pedido["cliente_id"])), D(str(pedido.get("total", 0)))
            )
        except Exception:
            pass  # no bloquear la facturación si falla el stats

    logger.warning(
        "Estado pedido cambiado | id={id} | {anterior} → {nuevo} | por={admin}",
        id=str(pedido_id), anterior=pedido["estado"],
        nuevo=values.estado, admin=current_user.get("email"),
    )
    pedido_estado_cambios.labels(de=pedido["estado"], a=values.estado).inc()
    return updated


# ─── DELETE /pedidos/{id}/hard ────────────────────────────────────────────────

@router.delete(
    "/{pedido_id}/hard",
    status_code=status.HTTP_200_OK,
    summary="Eliminar pedido permanentemente",
    description="**Solo super_admin.** Solo en estado 'borrador' o 'cancelado'.",
)
@limiter.limit("5/hour", key_func=get_user_id_from_token)
def hard_delete_pedido_endpoint(
    request: Request,
    pedido_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_superadmin)],  # 🔒 solo super_admin
) -> dict:
    pedido = get_pedido(db, pedido_id)
    if not pedido:
        raise NotFoundException("Pedido no encontrado")
    if pedido["estado"] not in ("borrador", "cancelado"):
        raise BadRequestException(
            f"Solo se pueden eliminar pedidos en 'borrador' o 'cancelado'. "
            f"Estado actual: '{pedido['estado']}'"
        )
    hard_delete_pedido(db, pedido_id)
    logger.warning("Pedido ELIMINADO [hard] | id={id} | numero={num} | por={admin}",
                   id=str(pedido_id), num=pedido.get("numero_pedido"),
                   admin=current_user.get("email"))
    return {"message": f"Pedido '{pedido['numero_pedido']}' eliminado permanentemente"}


# ─── POST /pedidos/{id}/items ─────────────────────────────────────────────────

@router.post(
    "/{pedido_id}/items",
    response_model=DetallePedidoRead,
    status_code=status.HTTP_201_CREATED,
    summary="Agregar ítem al pedido",
    description="Solo en estado 'borrador' o 'abierto'. Totales recalculados automáticamente.",
)
@limiter.limit("120/hour", key_func=get_user_id_from_token)
def add_item(
    request: Request,
    pedido_id: UUID,
    data: DetallePedidoCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    pedido = _get_pedido_verificado(db, pedido_id, current_user)
    _verificar_editable(pedido)
    item = add_detalle_item(db, pedido_id, data, UUID(str(current_user["id"])))
    logger.info("Ítem agregado | pedido={id} | producto={prod} | por={admin}",
                id=str(pedido_id), prod=str(data.producto_id),
                admin=current_user.get("email"))
    return item


# ─── PATCH /pedidos/{id}/items/{item_id} ──────────────────────────────────────

@router.patch(
    "/{pedido_id}/items/{item_id}",
    response_model=DetallePedidoRead,
    summary="Actualizar ítem del pedido",
    description="Solo en 'borrador' o 'abierto'. Totales recalculados automáticamente.",
)
@limiter.limit("120/hour", key_func=get_user_id_from_token)
def patch_item(
    request: Request,
    pedido_id: UUID,
    item_id: UUID,
    values: DetallePedidoUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    pedido = _get_pedido_verificado(db, pedido_id, current_user)
    _verificar_editable(pedido)

    item = get_detalle_item(db, item_id)
    if not item or str(item["pedido_id"]) != str(pedido_id):
        raise NotFoundException("Ítem no encontrado en este pedido")
    if item["estado"] == "cancelado":
        raise BadRequestException("No se puede modificar un ítem cancelado")

    updated = update_detalle_item(db, item_id, values, pedido_id, UUID(str(current_user["id"])))
    if not updated:
        raise NotFoundException("No se pudo actualizar el ítem")
    return updated


# ─── DELETE /pedidos/{id}/items/{item_id} ─────────────────────────────────────

@router.delete(
    "/{pedido_id}/items/{item_id}",
    response_model=DetallePedidoRead,
    status_code=status.HTTP_200_OK,
    summary="Cancelar ítem del pedido",
    description="Cancela el ítem con motivo. Totales recalculados automáticamente.",
)
@limiter.limit("60/hour", key_func=get_user_id_from_token)
def cancel_item(
    request: Request,
    pedido_id: UUID,
    item_id: UUID,
    data: DetalleCancelacion,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    pedido = _get_pedido_verificado(db, pedido_id, current_user)

    if pedido["estado"] in ("facturado", "cancelado"):
        raise BadRequestException(
            f"No se pueden cancelar ítems de un pedido '{pedido['estado']}'"
        )

    item = get_detalle_item(db, item_id)
    if not item or str(item["pedido_id"]) != str(pedido_id):
        raise NotFoundException("Ítem no encontrado en este pedido")
    if item["estado"] == "cancelado":
        raise BadRequestException("El ítem ya está cancelado")

    updated = cancelar_detalle_item(
        db, item_id, pedido_id, data.motivo_cancelacion, UUID(str(current_user["id"]))
    )
    logger.warning(
        "Ítem cancelado | pedido={ped} | item={item} | motivo={motivo} | por={admin}",
        ped=str(pedido_id), item=str(item_id),
        motivo=data.motivo_cancelacion, admin=current_user.get("email"),
    )
    return updated