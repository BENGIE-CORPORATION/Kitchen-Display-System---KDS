"""
CRUD de Pagos y Divisiones de Cuenta.

Reglas clave:
  - El cambio (vuelto) se calcula automáticamente para pagos en efectivo.
  - Al registrar un pago completado se actualiza el estado_pago del pedido.
  - Un pedido puede tener múltiples pagos (pago mixto / split).
  - Las divisiones son opción de split de cuenta antes de pagar.
"""

from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID

from supabase import Client

from ..core.pagination import compute_offset, paginated_response
from ..models.pago import (
    SORTABLE_COLUMNS_DIVISIONES,
    SORTABLE_COLUMNS_PAGOS,
    TABLE_DETALLE_DIVISIONES,
    TABLE_DIVISIONES,
    TABLE_PAGOS,
)
from ..schemas.pago import DivisionCuentaCreate, PagoCreate


def _now() -> str:
    return datetime.now(UTC).isoformat()


def _safe_order(column: str, table: str = "pagos") -> str:
    cols = SORTABLE_COLUMNS_PAGOS if table == "pagos" else SORTABLE_COLUMNS_DIVISIONES
    return column if column in cols else "created_at"


def _serialize(payload: dict) -> dict:
    result = {}
    for key, value in payload.items():
        if isinstance(value, UUID):
            result[key] = str(value)
        elif isinstance(value, Decimal):
            result[key] = float(value)
        elif isinstance(value, datetime):
            result[key] = value.isoformat()
        elif hasattr(value, "isoformat"):  # date
            result[key] = value.isoformat()
        else:
            result[key] = value
    return result


def _calcular_estado_pago_pedido(db: Client, pedido_id: UUID) -> str:
    """
    Determina el estado_pago del pedido basándose en el total pagado
    vs el total del pedido.
    """
    pedido_result = (
        db.table("pedidos").select("total").eq("id", str(pedido_id)).limit(1).execute()
    )
    if not pedido_result.data:
        return "pendiente"

    total_pedido = Decimal(str(pedido_result.data[0]["total"]))

    pagos_result = (
        db.table(TABLE_PAGOS)
        .select("monto")
        .eq("pedido_id", str(pedido_id))
        .eq("estado", "completado")
        .execute()
    )
    total_pagado = sum(Decimal(str(p["monto"])) for p in pagos_result.data)

    if total_pagado <= 0:
        return "pendiente"
    elif total_pagado >= total_pedido:
        return "pagado"
    else:
        return "pago_parcial"


def _actualizar_estado_pago_pedido(db: Client, pedido_id: UUID) -> None:
    nuevo_estado = _calcular_estado_pago_pedido(db, pedido_id)
    db.table("pedidos").update({
        "estado_pago": nuevo_estado,
        "updated_at": _now(),
    }).eq("id", str(pedido_id)).execute()


# ══════════════════════════════════════════════════════════════════════════════
# PAGOS
# ══════════════════════════════════════════════════════════════════════════════

def numero_pago_exists(
    db: Client, pedido_id: UUID, numero_pago: str, exclude_id: UUID | None = None
) -> bool:
    query = (
        db.table(TABLE_PAGOS)
        .select("id")
        .eq("pedido_id", str(pedido_id))
        .eq("numero_pago", numero_pago)
    )
    if exclude_id:
        query = query.neq("id", str(exclude_id))
    return len(query.limit(1).execute().data) > 0


def create_pago(db: Client, pedido_id: UUID, data: PagoCreate, created_by: UUID) -> dict:
    """
    Registra el pago. Si es en efectivo, calcula el cambio automáticamente.
    Si el pago queda completado, actualiza el estado_pago del pedido.
    """
    payload = _serialize(data.model_dump())
    payload["pedido_id"] = str(pedido_id)
    payload["created_by"] = str(created_by)
    payload["estado"] = "completado"

    # Calcular cambio para pagos en efectivo
    if data.metodo_pago == "efectivo" and data.monto_recibido is not None:
        cambio = Decimal(str(data.monto_recibido)) - Decimal(str(data.monto))
        payload["cambio"] = float(max(Decimal("0"), cambio))

    result = db.table(TABLE_PAGOS).insert(payload).execute()
    pago = result.data[0]

    # Actualizar estado_pago del pedido
    _actualizar_estado_pago_pedido(db, pedido_id)

    return pago


def get_pago(db: Client, pago_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_PAGOS).select("*").eq("id", str(pago_id)).limit(1).execute()
    )
    return result.data[0] if result.data else None


def get_pagos_por_pedido(db: Client, pedido_id: UUID) -> list[dict]:
    result = (
        db.table(TABLE_PAGOS)
        .select("*")
        .eq("pedido_id", str(pedido_id))
        .order("created_at", desc=False)
        .execute()
    )
    return result.data


def get_pagos_por_sesion(
    db: Client,
    sesion_caja_id: UUID,
    page: int = 1,
    items_per_page: int = 50,
    metodo_pago: str | None = None,
    estado: str | None = None,
) -> dict:
    offset = compute_offset(page, items_per_page)
    query = (
        db.table(TABLE_PAGOS)
        .select("*", count="exact")
        .eq("sesion_caja_id", str(sesion_caja_id))
    )
    if metodo_pago:
        query = query.eq("metodo_pago", metodo_pago)
    if estado:
        query = query.eq("estado", estado)

    result = (
        query
        .order("created_at", desc=True)
        .range(offset, offset + items_per_page - 1)
        .execute()
    )
    return paginated_response(
        data=result.data, total=result.count or 0,
        page=page, items_per_page=items_per_page,
    )


def cambiar_estado_pago(db: Client, pago_id: UUID, nuevo_estado: str, pedido_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_PAGOS)
        .update({"estado": nuevo_estado})
        .eq("id", str(pago_id))
        .execute()
    )
    pago = result.data[0] if result.data else None
    if pago:
        _actualizar_estado_pago_pedido(db, pedido_id)
    return pago


def get_resumen_pagos_pedido(db: Client, pedido_id: UUID) -> dict:
    """Retorna totales agrupados por método de pago para un pedido."""
    pagos = (
        db.table(TABLE_PAGOS)
        .select("metodo_pago, monto, estado")
        .eq("pedido_id", str(pedido_id))
        .execute()
        .data
    )
    completados = [p for p in pagos if p["estado"] == "completado"]
    total_pagado = sum(Decimal(str(p["monto"])) for p in completados)
    por_metodo: dict = {}
    for p in completados:
        metodo = p["metodo_pago"]
        por_metodo[metodo] = float(
            Decimal(str(por_metodo.get(metodo, 0))) + Decimal(str(p["monto"]))
        )
    return {
        "total_pagado": float(total_pagado),
        "cantidad_pagos": len(completados),
        "por_metodo": por_metodo,
    }


# ══════════════════════════════════════════════════════════════════════════════
# DIVISIONES DE CUENTA
# ══════════════════════════════════════════════════════════════════════════════

def create_division(
    db: Client, pedido_id: UUID, data: DivisionCuentaCreate, created_by: UUID
) -> dict:
    division_payload = _serialize(data.model_dump(exclude={"items"}))
    division_payload["pedido_id"] = str(pedido_id)
    division_payload["created_by"] = str(created_by)
    division_payload["estado"] = "pendiente"

    division = db.table(TABLE_DIVISIONES).insert(division_payload).execute().data[0]

    if data.items:
        items_data = [_serialize(item.model_dump()) for item in data.items]
        for item in items_data:
            item["division_id"] = division["id"]
        db.table(TABLE_DETALLE_DIVISIONES).insert(items_data).execute()

    return division


def get_division(db: Client, division_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_DIVISIONES).select("*").eq("id", str(division_id)).limit(1).execute()
    )
    return result.data[0] if result.data else None


def get_division_con_detalle(db: Client, division_id: UUID) -> dict | None:
    division = get_division(db, division_id)
    if not division:
        return None
    items = (
        db.table(TABLE_DETALLE_DIVISIONES)
        .select("*")
        .eq("division_id", str(division_id))
        .execute()
        .data
    )
    division["items"] = items
    return division


def get_divisiones_por_pedido(db: Client, pedido_id: UUID) -> list[dict]:
    result = (
        db.table(TABLE_DIVISIONES)
        .select("*")
        .eq("pedido_id", str(pedido_id))
        .order("numero_division", desc=False)
        .execute()
    )
    return result.data


def marcar_division_pagada(db: Client, division_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_DIVISIONES)
        .update({"estado": "pagado"})
        .eq("id", str(division_id))
        .execute()
    )
    return result.data[0] if result.data else None


def delete_division(db: Client, division_id: UUID) -> bool:
    result = (
        db.table(TABLE_DIVISIONES).delete().eq("id", str(division_id)).execute()
    )
    return len(result.data) > 0