"""
CRUD de Métodos de Pago — toda la lógica de acceso a Supabase vive aquí.
Los routers NO deben contener queries directas.
"""

from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID

from supabase import Client

from ..core.pagination import compute_offset, paginated_response
from ..models.metodo_pago import SORTABLE_COLUMNS_METODOS_PAGO, TABLE_METODOS_PAGO
from ..schemas.metodo_pago import MetodoPagoCreate, MetodoPagoUpdate


def _now() -> str:
    return datetime.now(UTC).isoformat()


def _safe_order(column: str) -> str:
    return column if column in SORTABLE_COLUMNS_METODOS_PAGO else "created_at"


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

def metodo_pago_codigo_exists(
    db: Client,
    empresa_id: UUID,
    codigo: str,
    exclude_id: UUID | None = None,
) -> bool:
    query = (
        db.table(TABLE_METODOS_PAGO)
        .select("id")
        .eq("empresa_id", str(empresa_id))
        .eq("codigo", codigo.lower())
    )
    if exclude_id:
        query = query.neq("id", str(exclude_id))
    return len(query.limit(1).execute().data) > 0


# ─── CREATE ────────────────────────────────────────────────────────────────────

def create_metodo_pago(db: Client, data: MetodoPagoCreate, created_by: UUID) -> dict:
    payload = _serialize(data.model_dump())
    payload["is_active"] = True
    payload["created_by"] = str(created_by)
    result = db.table(TABLE_METODOS_PAGO).insert(payload).execute()
    return result.data[0]


# ─── READ ONE ──────────────────────────────────────────────────────────────────

def get_metodo_pago(db: Client, metodo_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_METODOS_PAGO)
        .select("*")
        .eq("id", str(metodo_id))
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


# ─── READ MANY ─────────────────────────────────────────────────────────────────

def get_metodos_pago(
    db: Client,
    empresa_id: UUID,
    page: int = 1,
    items_per_page: int = 50,
    order_by: str = "nombre",
    order_desc: bool = False,
    tipo: str | None = None,
    solo_activos: bool = True,
) -> dict:
    offset = compute_offset(page, items_per_page)

    query = (
        db.table(TABLE_METODOS_PAGO)
        .select("*", count="exact")
        .eq("empresa_id", str(empresa_id))
    )

    if solo_activos:
        query = query.eq("is_active", True)
    if tipo:
        query = query.eq("tipo", tipo)

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

def update_metodo_pago(
    db: Client, metodo_id: UUID, data: MetodoPagoUpdate, updated_by: UUID
) -> dict | None:
    payload = data.model_dump(exclude_unset=True)
    payload["updated_at"] = _now()
    payload["updated_by"] = str(updated_by)
    result = (
        db.table(TABLE_METODOS_PAGO)
        .update(payload)
        .eq("id", str(metodo_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── SOFT DELETE ───────────────────────────────────────────────────────────────

def soft_delete_metodo_pago(db: Client, metodo_id: UUID, updated_by: UUID) -> dict | None:
    result = (
        db.table(TABLE_METODOS_PAGO)
        .update({"is_active": False, "updated_at": _now(), "updated_by": str(updated_by)})
        .eq("id", str(metodo_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── HARD DELETE ───────────────────────────────────────────────────────────────

def hard_delete_metodo_pago(db: Client, metodo_id: UUID) -> bool:
    result = (
        db.table(TABLE_METODOS_PAGO)
        .delete()
        .eq("id", str(metodo_id))
        .execute()
    )
    return len(result.data) > 0
