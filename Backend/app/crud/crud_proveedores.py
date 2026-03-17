"""
CRUD de Proveedores.
"""

from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID

from supabase import Client

from ..core.pagination import compute_offset, paginated_response
from ..models.proveedor import SORTABLE_COLUMNS, TABLE_NAME
from ..schemas.proveedor import ProveedorCreateInternal, ProveedorUpdateInternal


def _now() -> str:
    return datetime.now(UTC).isoformat()


def _safe_order(column: str) -> str:
    return column if column in SORTABLE_COLUMNS else "created_at"


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


# ─── EXISTS ───────────────────────────────────────────────────────────────────

def proveedor_identificacion_exists(
    db: Client,
    empresa_id: UUID,
    identificacion: str,
    exclude_id: UUID | None = None,
) -> bool:
    query = (
        db.table(TABLE_NAME)
        .select("id")
        .eq("empresa_id", str(empresa_id))
        .eq("identificacion", identificacion.upper())
    )
    if exclude_id:
        query = query.neq("id", str(exclude_id))
    return len(query.limit(1).execute().data) > 0


def proveedor_codigo_exists(
    db: Client,
    empresa_id: UUID,
    codigo: str,
    exclude_id: UUID | None = None,
) -> bool:
    query = (
        db.table(TABLE_NAME)
        .select("id")
        .eq("empresa_id", str(empresa_id))
        .eq("codigo", codigo.upper())
    )
    if exclude_id:
        query = query.neq("id", str(exclude_id))
    return len(query.limit(1).execute().data) > 0


# ─── CREATE ───────────────────────────────────────────────────────────────────

def create_proveedor(db: Client, data: ProveedorCreateInternal) -> dict:
    payload = _serialize(data.model_dump(exclude_none=False))
    result = db.table(TABLE_NAME).insert(payload).execute()
    return result.data[0]


# ─── READ ONE ─────────────────────────────────────────────────────────────────

def get_proveedor(db: Client, proveedor_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_NAME)
        .select("*")
        .eq("id", str(proveedor_id))
        .neq("estado", "inactivo")
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


# ─── READ MANY ────────────────────────────────────────────────────────────────

def get_proveedores(
    db: Client,
    empresa_id: UUID,
    page: int = 1,
    items_per_page: int = 20,
    order_by: str = "created_at",
    order_desc: bool = True,
    tipo_proveedor: str | None = None,
    condicion_pago: str | None = None,
    estado: str | None = None,
    search: str | None = None,
) -> dict:
    offset = compute_offset(page, items_per_page)

    query = (
        db.table(TABLE_NAME)
        .select("*", count="exact")
        .eq("empresa_id", str(empresa_id))
        .neq("estado", "inactivo")
    )

    if tipo_proveedor:
        query = query.eq("tipo_proveedor", tipo_proveedor)
    if condicion_pago:
        query = query.eq("condicion_pago", condicion_pago)
    if estado:
        query = query.eq("estado", estado)
    if search:
        query = query.ilike("nombre_legal", f"%{search}%")

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


# ─── UPDATE ───────────────────────────────────────────────────────────────────

def update_proveedor(
    db: Client, proveedor_id: UUID, data: ProveedorUpdateInternal
) -> dict | None:
    payload = _serialize(data.model_dump(exclude_unset=True))
    payload["updated_at"] = _now()
    result = (
        db.table(TABLE_NAME)
        .update(payload)
        .eq("id", str(proveedor_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── SOFT DELETE ──────────────────────────────────────────────────────────────

def soft_delete_proveedor(db: Client, proveedor_id: UUID, updated_by: UUID) -> dict | None:
    result = (
        db.table(TABLE_NAME)
        .update({"estado": "inactivo", "updated_at": _now(), "updated_by": str(updated_by)})
        .eq("id", str(proveedor_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── HARD DELETE ─────────────────────────────────────────────────────────────

def hard_delete_proveedor(db: Client, proveedor_id: UUID) -> bool:
    result = (
        db.table(TABLE_NAME)
        .delete()
        .eq("id", str(proveedor_id))
        .execute()
    )
    return len(result.data) > 0