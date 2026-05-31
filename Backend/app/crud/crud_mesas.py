"""
CRUD de Mesas — toda la lógica de acceso a Supabase vive aquí.
Los routers NO deben contener queries directas.
"""

from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID

from supabase import Client

from ..core.pagination import compute_offset, paginated_response
from ..models.mesa import SORTABLE_COLUMNS_MESAS, TABLE_MESAS
from ..schemas.mesa import MesaCreate, MesaEstadoUpdate, MesaUpdate

TABLE_PEDIDOS = "pedidos"
ESTADOS_PEDIDO_TERMINAL = ("facturado", "cancelado")


def _now() -> str:
    return datetime.now(UTC).isoformat()


def _safe_order(column: str) -> str:
    return column if column in SORTABLE_COLUMNS_MESAS else "created_at"


def _serialize(payload: dict) -> dict:
    result = {}
    for key, value in payload.items():
        if isinstance(value, UUID):
            result[key] = str(value)
        elif isinstance(value, Decimal):
            result[key] = float(value)
        elif isinstance(value, datetime):
            result[key] = value.isoformat()
        else:
            result[key] = value
    return result


# ─── EXISTS ────────────────────────────────────────────────────────────────────

def mesa_numero_exists(
    db: Client,
    sucursal_id: UUID,
    numero: str,
    exclude_id: UUID | None = None,
) -> bool:
    query = (
        db.table(TABLE_MESAS)
        .select("id")
        .eq("sucursal_id", str(sucursal_id))
        .eq("numero", numero.upper())
        .eq("is_active", True)
    )
    if exclude_id:
        query = query.neq("id", str(exclude_id))
    return len(query.limit(1).execute().data) > 0


# ─── CREATE ────────────────────────────────────────────────────────────────────

def create_mesa(db: Client, data: MesaCreate, created_by: UUID) -> dict:
    payload = _serialize(data.model_dump())
    payload["estado"] = "libre"
    payload["is_active"] = True
    payload["created_by"] = str(created_by)
    result = db.table(TABLE_MESAS).insert(payload).execute()
    return result.data[0]


# ─── READ ONE ──────────────────────────────────────────────────────────────────

def get_mesa(db: Client, mesa_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_MESAS)
        .select("*")
        .eq("id", str(mesa_id))
        .eq("is_active", True)
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def get_mesa_raw(db: Client, mesa_id: UUID) -> dict | None:
    """Sin filtro is_active — para hard delete y validaciones internas."""
    result = (
        db.table(TABLE_MESAS)
        .select("*")
        .eq("id", str(mesa_id))
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def get_pedido_activo_mesa(db: Client, mesa_id: UUID) -> dict | None:
    """Retorna el pedido no terminal más reciente de la mesa."""
    result = (
        db.table(TABLE_PEDIDOS)
        .select("*")
        .eq("mesa_id", str(mesa_id))
        .not_.in_("estado", list(ESTADOS_PEDIDO_TERMINAL))
        .order("created_at", desc=True)
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


# ─── READ MANY ─────────────────────────────────────────────────────────────────

def get_mesas(
    db: Client,
    sucursal_id: UUID,
    page: int = 1,
    items_per_page: int = 50,
    order_by: str = "numero",
    order_desc: bool = False,
    estado: str | None = None,
    zona: str | None = None,
) -> dict:
    offset = compute_offset(page, items_per_page)

    query = (
        db.table(TABLE_MESAS)
        .select("*", count="exact")
        .eq("sucursal_id", str(sucursal_id))
        .eq("is_active", True)
    )

    if estado:
        query = query.eq("estado", estado)
    if zona:
        query = query.eq("zona", zona)

    result = (
        query
        .order(_safe_order(order_by), desc=order_desc)
        .range(offset, offset + items_per_page - 1)
        .execute()
    )

    return paginated_response(
        data=result.data,
        total=result.count or 0,
        page=page,
        items_per_page=items_per_page,
    )


# ─── UPDATE ────────────────────────────────────────────────────────────────────

def update_mesa(db: Client, mesa_id: UUID, data: MesaUpdate, updated_by: UUID) -> dict | None:
    payload = data.model_dump(exclude_unset=True)
    payload["updated_at"] = _now()
    payload["updated_by"] = str(updated_by)
    result = (
        db.table(TABLE_MESAS)
        .update(payload)
        .eq("id", str(mesa_id))
        .execute()
    )
    return result.data[0] if result.data else None


def update_estado_mesa(
    db: Client, mesa_id: UUID, data: MesaEstadoUpdate, updated_by: UUID
) -> dict | None:
    result = (
        db.table(TABLE_MESAS)
        .update({
            "estado": data.estado,
            "updated_at": _now(),
            "updated_by": str(updated_by),
        })
        .eq("id", str(mesa_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── SOFT DELETE ───────────────────────────────────────────────────────────────

def soft_delete_mesa(db: Client, mesa_id: UUID, updated_by: UUID) -> dict | None:
    result = (
        db.table(TABLE_MESAS)
        .update({"is_active": False, "updated_at": _now(), "updated_by": str(updated_by)})
        .eq("id", str(mesa_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── HARD DELETE ───────────────────────────────────────────────────────────────

def hard_delete_mesa(db: Client, mesa_id: UUID) -> bool:
    result = (
        db.table(TABLE_MESAS)
        .delete()
        .eq("id", str(mesa_id))
        .execute()
    )
    return len(result.data) > 0
