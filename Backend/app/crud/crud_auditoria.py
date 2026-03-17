"""
CRUD de Auditoría, Historial de Estados de Pedido y Detalle.

Uso:
  - El historial de pedidos/detalle se inserta automáticamente al cambiar estado.
  - La auditoría general se inserta desde endpoints críticos o middleware.
  - Todas las tablas son append-only — no hay update ni delete.
  - Las consultas son de solo lectura para los routers.
"""

from datetime import UTC, datetime
from uuid import UUID

from supabase import Client

from ..core.pagination import compute_offset, paginated_response
from ..models.auditoria import (
    SORTABLE_COLUMNS_AUDITORIA,
    SORTABLE_COLUMNS_HISTORIAL,
    TABLE_AUDITORIA,
    TABLE_HISTORIAL_DETALLE,
    TABLE_HISTORIAL_PEDIDO,
)
from ..schemas.auditoria import (
    AuditoriaCreate,
    HistorialEstadetalleCreate,
    HistorialEstadoPedidoCreate,
)


def _now() -> str:
    return datetime.now(UTC).isoformat()


def _safe_order_historial(column: str) -> str:
    return column if column in SORTABLE_COLUMNS_HISTORIAL else "created_at"


def _safe_order_auditoria(column: str) -> str:
    return column if column in SORTABLE_COLUMNS_AUDITORIA else "created_at"


def _serialize_jsonb(payload: dict) -> dict:
    """Convierte UUIDs y datetimes en el payload para Supabase."""
    result = {}
    for key, value in payload.items():
        if isinstance(value, UUID):
            result[key] = str(value)
        elif isinstance(value, datetime):
            result[key] = value.isoformat()
        elif isinstance(value, dict):
            result[key] = _serialize_jsonb(value)
        else:
            result[key] = value
    return result


# ══════════════════════════════════════════════════════════════════════════════
# HISTORIAL DE ESTADOS — PEDIDO
# ══════════════════════════════════════════════════════════════════════════════

def registrar_cambio_estado_pedido(
    db: Client, data: HistorialEstadoPedidoCreate
) -> dict:
    """
    Registra un cambio de estado en el historial del pedido.
    Llamar desde crud_pedidos.cambiar_estado_pedido y update_pedido.
    """
    payload = _serialize_jsonb(data.model_dump(exclude_none=False))
    result = db.table(TABLE_HISTORIAL_PEDIDO).insert(payload).execute()
    return result.data[0]


def get_historial_pedido(
    db: Client,
    pedido_id: UUID,
    page: int = 1,
    items_per_page: int = 50,
    campo_modificado: str | None = None,
) -> dict:
    offset = compute_offset(page, items_per_page)

    query = (
        db.table(TABLE_HISTORIAL_PEDIDO)
        .select("*", count="exact")
        .eq("pedido_id", str(pedido_id))
    )
    if campo_modificado:
        query = query.eq("campo_modificado", campo_modificado)

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


# ══════════════════════════════════════════════════════════════════════════════
# HISTORIAL DE ESTADOS — DETALLE PEDIDO
# ══════════════════════════════════════════════════════════════════════════════

def registrar_cambio_estado_detalle(
    db: Client, data: HistorialEstadetalleCreate
) -> dict:
    """
    Registra un cambio de estado en el historial de un ítem de pedido.
    Llamar desde crud_pedidos al cancelar o cambiar estado de un ítem.
    """
    payload = _serialize_jsonb(data.model_dump(exclude_none=False))
    result = db.table(TABLE_HISTORIAL_DETALLE).insert(payload).execute()
    return result.data[0]


def get_historial_detalle(
    db: Client,
    detalle_pedido_id: UUID,
    page: int = 1,
    items_per_page: int = 50,
) -> dict:
    offset = compute_offset(page, items_per_page)
    result = (
        db.table(TABLE_HISTORIAL_DETALLE)
        .select("*", count="exact")
        .eq("detalle_pedido_id", str(detalle_pedido_id))
        .order("created_at", desc=True)
        .range(offset, offset + items_per_page - 1)
        .execute()
    )
    return paginated_response(
        data=result.data, total=result.count or 0,
        page=page, items_per_page=items_per_page,
    )


# ══════════════════════════════════════════════════════════════════════════════
# AUDITORÍA GENERAL
# ══════════════════════════════════════════════════════════════════════════════

def registrar_auditoria(db: Client, data: AuditoriaCreate) -> dict:
    """
    Registra un evento de auditoría.
    Llamar desde endpoints críticos: login, cambios de permisos,
    eliminaciones, cambios de precios, etc.
    """
    payload = _serialize_jsonb(data.model_dump(exclude_none=False))
    result = db.table(TABLE_AUDITORIA).insert(payload).execute()
    return result.data[0]


def get_auditoria(
    db: Client,
    page: int = 1,
    items_per_page: int = 50,
    order_by: str = "created_at",
    order_desc: bool = True,
    empresa_id: UUID | None = None,
    sucursal_id: UUID | None = None,
    usuario_id: UUID | None = None,
    modulo: str | None = None,
    tabla: str | None = None,
    accion: str | None = None,
    registro_id: UUID | None = None,
    fecha_desde: datetime | None = None,
    fecha_hasta: datetime | None = None,
) -> dict:
    offset = compute_offset(page, items_per_page)

    query = db.table(TABLE_AUDITORIA).select("*", count="exact")

    if empresa_id:
        query = query.eq("empresa_id", str(empresa_id))
    if sucursal_id:
        query = query.eq("sucursal_id", str(sucursal_id))
    if usuario_id:
        query = query.eq("usuario_id", str(usuario_id))
    if modulo:
        query = query.eq("modulo", modulo)
    if tabla:
        query = query.eq("tabla", tabla)
    if accion:
        query = query.eq("accion", accion)
    if registro_id:
        query = query.eq("registro_id", str(registro_id))
    if fecha_desde:
        query = query.gte("created_at", fecha_desde.isoformat())
    if fecha_hasta:
        query = query.lte("created_at", fecha_hasta.isoformat())

    result = (
        query
        .order(_safe_order_auditoria(order_by), desc=order_desc)
        .range(offset, offset + items_per_page - 1)
        .execute()
    )
    return paginated_response(
        data=result.data, total=result.count or 0,
        page=page, items_per_page=items_per_page,
    )


def get_auditoria_por_registro(
    db: Client, tabla: str, registro_id: UUID
) -> list[dict]:
    """Retorna todo el historial de cambios de un registro específico."""
    result = (
        db.table(TABLE_AUDITORIA)
        .select("*")
        .eq("tabla", tabla)
        .eq("registro_id", str(registro_id))
        .order("created_at", desc=True)
        .execute()
    )
    return result.data