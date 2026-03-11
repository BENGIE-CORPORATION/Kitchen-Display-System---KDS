"""
CRUD de Categorías — toda la lógica de acceso a Supabase vive aquí.
Los routers NO deben contener queries directas.
"""

from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID

from supabase import Client

from ..core.pagination import compute_offset, paginated_response
from ..models.categoria import SORTABLE_COLUMNS, TABLE_NAME
from ..schemas.categoria import CategoriaCreateInternal, CategoriaUpdateInternal


def _now() -> str:
    return datetime.now(UTC).isoformat()


def _safe_order(column: str) -> str:
    return column if column in SORTABLE_COLUMNS else "created_at"


def _serialize(payload: dict) -> dict:
    """Convierte UUID y Decimal a tipos JSON-serializables para Supabase."""
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

def categoria_exists(db: Client, **filters) -> bool:
    query = db.table(TABLE_NAME).select("id")
    for key, value in filters.items():
        query = query.eq(key, value)
    return len(query.limit(1).execute().data) > 0


def categoria_codigo_exists(db: Client, empresa_id: UUID, codigo: str, exclude_id: UUID | None = None) -> bool:
    """Verifica unicidad de código dentro de la empresa. Excluye el propio registro en updates."""
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

def create_categoria(db: Client, data: CategoriaCreateInternal) -> dict:
    payload = _serialize(data.model_dump(exclude_none=False))
    if payload.get("codigo"):
        payload["codigo"] = payload["codigo"].upper()
    result = db.table(TABLE_NAME).insert(payload).execute()
    return result.data[0]


# ─── READ ONE ─────────────────────────────────────────────────────────────────

def get_categoria(db: Client, categoria_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_NAME)
        .select("*")
        .eq("id", str(categoria_id))
        .neq("estado", "inactivo")
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def get_categoria_raw(db: Client, categoria_id: UUID) -> dict | None:
    """Sin filtro de estado — para hard delete y validaciones internas."""
    result = (
        db.table(TABLE_NAME)
        .select("*")
        .eq("id", str(categoria_id))
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


# ─── READ MANY ────────────────────────────────────────────────────────────────

def get_categorias(
    db: Client,
    empresa_id: UUID,
    page: int = 1,
    items_per_page: int = 20,
    order_by: str = "orden",
    order_desc: bool = False,
    tipo: str | None = None,
    estado: str | None = None,
    categoria_padre_id: UUID | None = None,
    solo_raices: bool = False,     # True → solo categorías sin padre
) -> dict:
    offset = compute_offset(page, items_per_page)

    query = (
        db.table(TABLE_NAME)
        .select("*", count="exact")
        .eq("empresa_id", str(empresa_id))
        .neq("estado", "inactivo")
    )

    if tipo:
        query = query.eq("tipo", tipo)
    if estado:
        query = query.eq("estado", estado)
    if categoria_padre_id:
        query = query.eq("categoria_padre_id", str(categoria_padre_id))
    if solo_raices:
        query = query.is_("categoria_padre_id", "null")

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


def get_subcategorias(db: Client, categoria_padre_id: UUID) -> list[dict]:
    """Retorna todas las subcategorías directas de una categoría padre."""
    result = (
        db.table(TABLE_NAME)
        .select("*")
        .eq("categoria_padre_id", str(categoria_padre_id))
        .neq("estado", "inactivo")
        .order("orden", desc=False)
        .execute()
    )
    return result.data


# ─── UPDATE ───────────────────────────────────────────────────────────────────

def update_categoria(db: Client, categoria_id: UUID, data: CategoriaUpdateInternal) -> dict | None:
    payload = data.model_dump(exclude_unset=True)
    if payload.get("codigo"):
        payload["codigo"] = payload["codigo"].upper()
    payload["updated_at"] = _now()

    result = (
        db.table(TABLE_NAME)
        .update(payload)
        .eq("id", str(categoria_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── SOFT DELETE ──────────────────────────────────────────────────────────────

def soft_delete_categoria(db: Client, categoria_id: UUID, updated_by: UUID) -> dict | None:
    """
    Soft delete: marca la categoría como 'inactivo'.
    No desactiva subcategorías automáticamente — el router debe advertirlo.
    """
    result = (
        db.table(TABLE_NAME)
        .update({"estado": "inactivo", "updated_at": _now(), "updated_by": str(updated_by)})
        .eq("id", str(categoria_id))
        .execute()
    )
    return result.data[0] if result.data else None


def soft_delete_subcategorias(db: Client, categoria_padre_id: UUID, updated_by: UUID) -> int:
    """Desactiva todas las subcategorías de una categoría padre. Retorna el conteo afectado."""
    result = (
        db.table(TABLE_NAME)
        .update({"estado": "inactivo", "updated_at": _now(), "updated_by": str(updated_by)})
        .eq("categoria_padre_id", str(categoria_padre_id))
        .neq("estado", "inactivo")
        .execute()
    )
    return len(result.data)


# ─── HARD DELETE ─────────────────────────────────────────────────────────────

def hard_delete_categoria(db: Client, categoria_id: UUID) -> bool:
    """
    Borra físicamente la categoría.
    Las subcategorías quedan huérfanas (categoria_padre_id apunta a un ID inexistente).
    El router debe advertir esto o eliminarlas primero.
    """
    result = (
        db.table(TABLE_NAME)
        .delete()
        .eq("id", str(categoria_id))
        .execute()
    )
    return len(result.data) > 0