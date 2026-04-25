"""
CRUD de Sucursales.
Tabla: public.sucursales

Reglas de sincronización críticas:
- Una sucursal siempre debe pertenecer a una empresa existente y activa
- El codigo debe ser único POR empresa (no globalmente)
- Si se desactiva una sucursal, los usuarios asignados quedan sin acceso
  → por eso soft_delete también desactiva sus asignaciones en usuarios_sucursales
"""

from datetime import UTC, datetime
from uuid import UUID

from supabase import Client

from ..core.pagination import compute_offset, paginated_response
from ..models.sucursal import SORTABLE_COLUMNS, TABLE_NAME
from ..schemas.sucursal import SucursalCreateInternal, SucursalUpdateInternal


def _now() -> str:
    return datetime.now(UTC).isoformat()


def _safe_col(col: str) -> str:
    return col if col in SORTABLE_COLUMNS else "created_at"


# ─── EXISTS ───────────────────────────────────────────────────────────────────

def sucursal_exists_by_id(db: Client, sucursal_id: UUID) -> bool:
    result = (
        db.table(TABLE_NAME).select("id")
        .eq("id", str(sucursal_id)).limit(1).execute()
    )
    return len(result.data) > 0


def sucursal_codigo_exists(db: Client, empresa_id: UUID, codigo: str, exclude_id: UUID | None = None) -> bool:
    """Verifica si el código ya existe dentro de la empresa (unique constraint)."""
    query = (
        db.table(TABLE_NAME).select("id")
        .eq("empresa_id", str(empresa_id))
        .eq("codigo", codigo)
    )
    if exclude_id:
        query = query.neq("id", str(exclude_id))
    result = query.limit(1).execute()
    return len(result.data) > 0


# ─── CREATE ───────────────────────────────────────────────────────────────────

def create_sucursal(db: Client, sucursal: SucursalCreateInternal) -> dict:
    payload = sucursal.model_dump()
    # Serializar tipos especiales para Supabase
    for field in ("id", "empresa_id", "created_by"):
        if payload.get(field):
            payload[field] = str(payload[field])
    # time → string HH:MM:SS
    for field in ("horario_apertura", "horario_cierre"):
        if payload.get(field):
            payload[field] = str(payload[field])
    # Decimal → float
    for field in ("coordenadas_lat", "coordenadas_lng"):
        if payload.get(field) is not None:
            payload[field] = float(payload[field])

    result = db.table(TABLE_NAME).insert(payload).execute()
    return result.data[0]


# ─── READ ─────────────────────────────────────────────────────────────────────

def get_sucursal(db: Client, sucursal_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_NAME).select("*")
        .eq("id", str(sucursal_id))
        .neq("estado", "inactivo")
        .limit(1).execute()
    )
    return result.data[0] if result.data else None


def get_sucursal_by_codigo(db: Client, empresa_id: UUID, codigo: str) -> dict | None:
    result = (
        db.table(TABLE_NAME).select("*")
        .eq("empresa_id", str(empresa_id))
        .eq("codigo", codigo)
        .limit(1).execute()
    )
    return result.data[0] if result.data else None


def get_sucursales(
    db: Client,
    empresa_id: UUID | None,  # ← cambiar UUID a UUID | None
    page: int = 1,
    items_per_page: int = 10,
    order_by: str = "created_at",
    order_desc: bool = True,
    estado: str | None = None,
    tipo: str | None = None,
    ciudad: str | None = None,
) -> dict:
    offset = compute_offset(page, items_per_page)
    safe_col = _safe_col(order_by)

    query = (
        db.table(TABLE_NAME).select("*", count="exact")
        .neq("estado", "inactivo")
    )

    # ← solo filtrar por empresa si se especifica
    if empresa_id is not None:
        query = query.eq("empresa_id", str(empresa_id))

    if estado:
        query = query.eq("estado", estado)
    if tipo:
        query = query.eq("tipo", tipo)
    if ciudad:
        query = query.ilike("ciudad", f"%{ciudad}%")

    result = (
        query.order(safe_col, desc=order_desc)
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

def update_sucursal(db: Client, sucursal_id: UUID, data: SucursalUpdateInternal) -> dict | None:
    payload = data.model_dump(exclude_unset=True, exclude_none=True)
    payload["updated_at"] = _now()

    # Serializar tipos especiales
    for field in ("updated_by",):
        if payload.get(field):
            payload[field] = str(payload[field])
    for field in ("horario_apertura", "horario_cierre"):
        if payload.get(field):
            payload[field] = str(payload[field])
    for field in ("coordenadas_lat", "coordenadas_lng"):
        if payload.get(field) is not None:
            payload[field] = float(payload[field])

    result = (
        db.table(TABLE_NAME).update(payload)
        .eq("id", str(sucursal_id)).execute()
    )
    return result.data[0] if result.data else None


# ─── SOFT DELETE ─────────────────────────────────────────────────────────────
# ⚠️ SINCRONIZACIÓN CRÍTICA: al desactivar sucursal, desactivar sus asignaciones

def soft_delete_sucursal(db: Client, sucursal_id: UUID, deleted_by: UUID) -> dict | None:
    """
    Soft delete de sucursal.
    SINCRONIZACIÓN: también desactiva todas las asignaciones usuarios_sucursales
    para evitar que empleados queden con acceso fantasma a una sucursal inactiva.
    """
    now = _now()

    # 1. Desactivar la sucursal
    result = (
        db.table(TABLE_NAME)
        .update({"estado": "inactivo", "updated_at": now, "updated_by": str(deleted_by)})
        .eq("id", str(sucursal_id)).execute()
    )

    # 2. SINCRONIZACIÓN: desactivar todas las asignaciones de esta sucursal
    # Si esto falla, los empleados quedarían con acceso a una sucursal inactiva
    try:
        db.table("usuarios_sucursales").update(
            {"estado": "inactivo", "updated_at": now}
        ).eq("sucursal_id", str(sucursal_id)).eq("estado", "activo").execute()
    except Exception as e:
        # Log crítico — la sucursal se desactivó pero las asignaciones no
        # En producción aquí iría una alerta a Sentry/logging
        print(f"[CRÍTICO] Sucursal {sucursal_id} desactivada pero asignaciones NO. Error: {e}")

    return result.data[0] if result.data else None


def hard_delete_sucursal(db: Client, sucursal_id: UUID) -> bool:
    """
    Hard delete — también elimina asignaciones de usuarios_sucursales.
    Solo super_admin.
    """
    # 1. Eliminar asignaciones primero (FK constraint)
    db.table("usuarios_sucursales").delete().eq("sucursal_id", str(sucursal_id)).execute()
    # 2. Eliminar sucursal
    result = db.table(TABLE_NAME).delete().eq("id", str(sucursal_id)).execute()
    return len(result.data) > 0
