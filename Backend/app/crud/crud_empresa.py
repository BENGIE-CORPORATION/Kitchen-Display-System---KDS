"""
CRUD de Empresas — toda la lógica de acceso a Supabase vive aquí.
Los routers NO deben contener queries directas.
"""

from datetime import UTC, datetime
from uuid import UUID

from supabase import Client

from ..core.pagination import compute_offset, paginated_response
from ..models.empresa import FILTERABLE_COLUMNS, SORTABLE_COLUMNS, TABLE_NAME
from ..schemas.empresa import (
    EmpresaCreateInternal,
    EmpresaDelete,
    EmpresaRead,
    EmpresaUpdateInternal,
)


# ─── Helpers internos ─────────────────────────────────────────────────────────

def _now() -> str:
    return datetime.now(UTC).isoformat()


def _safe_order_column(column: str) -> str:
    """Whitelist de columnas para evitar SQL injection en ordenamiento."""
    if column not in SORTABLE_COLUMNS:
        return "created_at"
    return column


# ─── EXISTS ───────────────────────────────────────────────────────────────────

def empresa_exists(db: Client, **filters) -> bool:
    """Verifica si existe una empresa con los filtros dados."""
    query = db.table(TABLE_NAME).select("id")
    for key, value in filters.items():
        query = query.eq(key, value)
    result = query.limit(1).execute()
    return len(result.data) > 0


# ─── CREATE ───────────────────────────────────────────────────────────────────

def create_empresa(db: Client, empresa: EmpresaCreateInternal) -> dict:
    """Inserta una nueva empresa y retorna el registro creado."""
    payload = empresa.model_dump(exclude_none=False)
    result = db.table(TABLE_NAME).insert(payload).execute()
    return result.data[0]


# ─── READ ONE ─────────────────────────────────────────────────────────────────

def get_empresa(db: Client, empresa_id: UUID) -> dict | None:
    """Retorna una empresa por ID. None si no existe."""
    result = (
        db.table(TABLE_NAME)
        .select("*")
        .eq("id", str(empresa_id))
        .neq("estado", "inactivo")   # soft-delete: no retorna inactivas
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def get_empresa_by_identificacion(db: Client, identificacion: str) -> dict | None:
    """Retorna una empresa por su RUC/Tax ID."""
    result = (
        db.table(TABLE_NAME)
        .select("*")
        .eq("identificacion", identificacion)
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


# ─── READ MANY (con paginación y filtros) ─────────────────────────────────────

def get_empresas(
    db: Client,
    page: int = 1,
    items_per_page: int = 10,
    order_by: str = "created_at",
    order_desc: bool = True,
    # Filtros opcionales
    estado: str | None = None,
    tipo_negocio: str | None = None,
    pais: str | None = None,
    empresa_id: str | None = None, 
) -> dict:
    """
    Lista empresas con paginación, ordenamiento y filtros opcionales.
    Excluye empresas con estado 'inactivo' (soft delete).
    """
    safe_column = _safe_order_column(order_by)
    offset = compute_offset(page, items_per_page)

    # ── Query de datos ──
    query = db.table(TABLE_NAME).select("*", count="exact").neq("estado", "inactivo")

    # Filtros dinámicos
    if empresa_id:
        query = query.eq("id", str(empresa_id))
    if estado:
        query = query.eq("estado", estado)
    if tipo_negocio:
        query = query.eq("tipo_negocio", tipo_negocio)
    if pais:
        query = query.eq("pais", pais)

    result = (
        query
        .order(safe_column, desc=order_desc)
        .range(offset, offset + items_per_page - 1)
        .execute()
    )

    total = result.count or 0
    return paginated_response(
        data=result.data,
        total=total,
        page=page,
        items_per_page=items_per_page,
    )


# ─── UPDATE ───────────────────────────────────────────────────────────────────

def update_empresa(db: Client, empresa_id: UUID, update_data: EmpresaUpdateInternal) -> dict | None:
    """
    Actualiza campos de una empresa. Solo envía a Supabase los campos
    que el cliente realmente mandó (exclude_unset=True).
    """
    payload = update_data.model_dump(exclude_unset=True)
    payload["updated_at"] = _now()

    result = (
        db.table(TABLE_NAME)
        .update(payload)
        .eq("id", str(empresa_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── SOFT DELETE ──────────────────────────────────────────────────────────────

def soft_delete_empresa(db: Client, empresa_id: UUID) -> dict | None:
    """
    Soft delete: marca la empresa como 'inactivo' en lugar de borrarla.
    """
    payload = EmpresaDelete(
        estado="inactivo",
        updated_at=datetime.now(UTC),
    ).model_dump()

    result = (
        db.table(TABLE_NAME)
        .update(payload)
        .eq("id", str(empresa_id))
        .execute()
    )
    return result.data[0] if result.data else None


# ─── HARD DELETE (solo superadmin) ───────────────────────────────────────────

def hard_delete_empresa(db: Client, empresa_id: UUID) -> bool:
    """Borra físicamente el registro. Solo para superadmin."""
    result = (
        db.table(TABLE_NAME)
        .delete()
        .eq("id", str(empresa_id))
        .execute()
    )
    return len(result.data) > 0