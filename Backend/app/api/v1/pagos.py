"""
Router de Pagos y Divisiones de Cuenta — solo lógica HTTP.

Seguridad:
  --- Pagos ---
  GET    /pedidos/{id}/pagos              → autenticado + misma empresa
  GET    /pedidos/{id}/pagos/resumen      → autenticado + misma empresa
  POST   /pedidos/{id}/pagos              → autenticado + sesión abierta
  PATCH  /pedidos/{id}/pagos/{pago_id}/estado → admin_empresa o super_admin
  GET    /cajas/sesiones/{sesion_id}/pagos → admin_empresa o super_admin

  --- Divisiones ---
  GET    /pedidos/{id}/divisiones              → autenticado + misma empresa
  GET    /pedidos/{id}/divisiones/{div_id}     → autenticado + misma empresa
  POST   /pedidos/{id}/divisiones              → autenticado
  PATCH  /pedidos/{id}/divisiones/{div_id}/pagar → autenticado
  DELETE /pedidos/{id}/divisiones/{div_id}     → admin_empresa o super_admin
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
    get_current_user,
    verify_empresa_access,
)
from ...crud.crud_cajas import get_sesion
from ...crud.crud_pagos import (
    cambiar_estado_pago,
    create_division,
    create_pago,
    delete_division,
    get_division,
    get_division_con_detalle,
    get_divisiones_por_pedido,
    get_pagos_por_pedido,
    get_pagos_por_sesion,
    get_resumen_pagos_pedido,
    marcar_division_pagada,
    numero_pago_exists,
)
from ...crud.crud_pedidos import get_pedido
from ...database import get_supabase
from ...schemas.pago import (
    DivisionCuentaCreate,
    DivisionCuentaRead,
    DivisionCuentaReadDetalle,
    DivisionEstadoUpdate,
    PagoCreate,
    PagoEstadoUpdate,
    PagoRead,
)

router = APIRouter(tags=["Pagos"])


def _get_pedido_verificado(db: Client, pedido_id: UUID, current_user: dict) -> dict:
    pedido = get_pedido(db, pedido_id)
    if not pedido:
        raise NotFoundException("Pedido no encontrado")
    verify_empresa_access(current_user, UUID(str(pedido["empresa_id"])))
    return pedido


# ══════════════════════════════════════════════════════════════════════════════
# PAGOS
# ══════════════════════════════════════════════════════════════════════════════

@router.get(
    "/pedidos/{pedido_id}/pagos",
    response_model=list[PagoRead],
    summary="Listar pagos de un pedido",
)
def read_pagos_pedido(
    pedido_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> list:
    _get_pedido_verificado(db, pedido_id, current_user)
    return get_pagos_por_pedido(db, pedido_id)


@router.get(
    "/pedidos/{pedido_id}/pagos/resumen",
    summary="Resumen de pagos de un pedido",
    description="Retorna total pagado y desglose por método de pago.",
)
def read_resumen_pagos(
    pedido_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    _get_pedido_verificado(db, pedido_id, current_user)
    return get_resumen_pagos_pedido(db, pedido_id)


@router.post(
    "/pedidos/{pedido_id}/pagos",
    response_model=PagoRead,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar pago",
    description="Registra un pago sobre el pedido. Calcula cambio automáticamente para efectivo.",
)
@limiter.limit("30/hour", key_func=get_user_id_from_token)
def write_pago(
    request: Request,
    pedido_id: UUID,
    data: PagoCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    pedido = _get_pedido_verificado(db, pedido_id, current_user)

    if pedido["estado"] in ("cancelado", "facturado"):
        raise BadRequestException(
            f"No se pueden registrar pagos en pedidos '{pedido['estado']}'"
        )
    if pedido["estado_pago"] == "pagado":
        raise BadRequestException("El pedido ya está completamente pagado")

    # Validar sesión de caja
    sesion = get_sesion(db, data.sesion_caja_id)
    if not sesion:
        raise NotFoundException("Sesión de caja no encontrada")
    if sesion["estado"] != "abierta":
        raise BadRequestException("La sesión de caja no está abierta")

    if numero_pago_exists(db, pedido_id, data.numero_pago):
        raise DuplicateValueException(
            f"El número de pago '{data.numero_pago}' ya existe en este pedido"
        )

    nuevo = create_pago(db, pedido_id, data, UUID(str(current_user["id"])))

    logger.info(
        "Pago registrado | pedido={ped} | metodo={met} | monto={monto} | por={admin}",
        ped=str(pedido_id), met=data.metodo_pago,
        monto=str(data.monto), admin=current_user.get("email"),
    )
    return nuevo


@router.patch(
    "/pedidos/{pedido_id}/pagos/{pago_id}/estado",
    response_model=PagoRead,
    summary="Reversar o rechazar un pago",
    description="Cambia el estado a 'reversado' o 'rechazado'. Recalcula el estado_pago del pedido.",
)
@limiter.limit("10/hour", key_func=get_user_id_from_token)
def patch_estado_pago(
    request: Request,
    pedido_id: UUID,
    pago_id: UUID,
    values: PagoEstadoUpdate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    _get_pedido_verificado(db, pedido_id, current_user)

    from ...crud.crud_pagos import get_pago
    pago = get_pago(db, pago_id)
    if not pago:
        raise NotFoundException("Pago no encontrado")
    if str(pago["pedido_id"]) != str(pedido_id):
        raise NotFoundException("El pago no pertenece a este pedido")
    if pago["estado"] != "completado":
        raise BadRequestException(
            f"Solo se pueden reversar/rechazar pagos completados. Estado actual: '{pago['estado']}'"
        )

    updated = cambiar_estado_pago(db, pago_id, values.estado, pedido_id)

    logger.warning(
        "Estado pago cambiado | pago={id} | {anterior} → {nuevo} | por={admin}",
        id=str(pago_id), anterior=pago["estado"],
        nuevo=values.estado, admin=current_user.get("email"),
    )
    return updated


@router.get(
    "/cajas/sesiones/{sesion_id}/pagos",
    response_model=PaginatedResponse[PagoRead],
    summary="Listar pagos de una sesión de caja",
)
def read_pagos_sesion(
    sesion_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
    page: Annotated[int, Query(ge=1)] = 1,
    items_per_page: Annotated[int, Query(ge=1, le=100)] = 50,
    metodo_pago: str | None = None,
    estado: str | None = None,
) -> dict:
    sesion = get_sesion(db, sesion_id)
    if not sesion:
        raise NotFoundException("Sesión de caja no encontrada")

    from ...crud.crud_cajas import get_caja
    from ...crud.crud_sucursales import get_sucursal
    caja = get_caja(db, UUID(str(sesion["caja_id"])))
    if caja:
        sucursal = get_sucursal(db, UUID(str(caja["sucursal_id"])))
        if sucursal:
            verify_empresa_access(current_user, UUID(str(sucursal["empresa_id"])))

    return get_pagos_por_sesion(
        db=db, sesion_caja_id=sesion_id, page=page,
        items_per_page=items_per_page, metodo_pago=metodo_pago, estado=estado,
    )


# ══════════════════════════════════════════════════════════════════════════════
# DIVISIONES DE CUENTA
# ══════════════════════════════════════════════════════════════════════════════

@router.get(
    "/pedidos/{pedido_id}/divisiones",
    response_model=list[DivisionCuentaRead],
    summary="Listar divisiones de cuenta de un pedido",
)
def read_divisiones(
    pedido_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> list:
    _get_pedido_verificado(db, pedido_id, current_user)
    return get_divisiones_por_pedido(db, pedido_id)


@router.get(
    "/pedidos/{pedido_id}/divisiones/{division_id}",
    response_model=DivisionCuentaReadDetalle,
    summary="Obtener división con detalle de ítems",
)
def read_division(
    pedido_id: UUID,
    division_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    _get_pedido_verificado(db, pedido_id, current_user)
    division = get_division_con_detalle(db, division_id)
    if not division or str(division["pedido_id"]) != str(pedido_id):
        raise NotFoundException("División no encontrada en este pedido")
    return division


@router.post(
    "/pedidos/{pedido_id}/divisiones",
    response_model=DivisionCuentaRead,
    status_code=status.HTTP_201_CREATED,
    summary="Crear división de cuenta",
    description="Divide la cuenta del pedido. Útil para split de cuenta entre comensales.",
)
@limiter.limit("20/hour", key_func=get_user_id_from_token)
def write_division(
    request: Request,
    pedido_id: UUID,
    data: DivisionCuentaCreate,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    pedido = _get_pedido_verificado(db, pedido_id, current_user)

    if pedido["estado"] in ("facturado", "cancelado"):
        raise BadRequestException(
            f"No se pueden crear divisiones en pedidos '{pedido['estado']}'"
        )

    nueva = create_division(db, pedido_id, data, UUID(str(current_user["id"])))

    logger.info(
        "División creada | pedido={ped} | tipo={tipo} | num={num} | por={admin}",
        ped=str(pedido_id), tipo=data.tipo_division,
        num=data.numero_division, admin=current_user.get("email"),
    )
    return nueva


@router.patch(
    "/pedidos/{pedido_id}/divisiones/{division_id}/pagar",
    response_model=DivisionCuentaRead,
    summary="Marcar división como pagada",
)
@limiter.limit("20/hour", key_func=get_user_id_from_token)
def pagar_division(
    request: Request,
    pedido_id: UUID,
    division_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_user)],  # 🔒 autenticado
) -> dict:
    _get_pedido_verificado(db, pedido_id, current_user)

    division = get_division(db, division_id)
    if not division or str(division["pedido_id"]) != str(pedido_id):
        raise NotFoundException("División no encontrada en este pedido")
    if division["estado"] == "pagado":
        raise BadRequestException("Esta división ya está pagada")

    updated = marcar_division_pagada(db, division_id)

    logger.info(
        "División pagada | pedido={ped} | division={div} | por={admin}",
        ped=str(pedido_id), div=str(division_id), admin=current_user.get("email"),
    )
    return updated


@router.delete(
    "/pedidos/{pedido_id}/divisiones/{division_id}",
    status_code=status.HTTP_200_OK,
    summary="Eliminar división de cuenta",
    description="Elimina la división y su detalle. Solo si está pendiente.",
)
@limiter.limit("10/hour", key_func=get_user_id_from_token)
def delete_division_endpoint(
    request: Request,
    pedido_id: UUID,
    division_id: UUID,
    db: Annotated[Client, Depends(get_supabase)],
    current_user: Annotated[dict, Depends(get_current_admin)],  # 🔒 admin o superior
) -> dict:
    _get_pedido_verificado(db, pedido_id, current_user)

    division = get_division(db, division_id)
    if not division or str(division["pedido_id"]) != str(pedido_id):
        raise NotFoundException("División no encontrada en este pedido")
    if division["estado"] == "pagado":
        raise BadRequestException("No se puede eliminar una división ya pagada")

    delete_division(db, division_id)

    logger.warning(
        "División eliminada | pedido={ped} | division={div} | por={admin}",
        ped=str(pedido_id), div=str(division_id), admin=current_user.get("email"),
    )
    return {"message": "División eliminada correctamente"}