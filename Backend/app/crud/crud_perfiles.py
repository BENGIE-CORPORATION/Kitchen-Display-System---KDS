"""
CRUD de Perfiles de Usuario.
Tabla: public.perfiles_usuario
El id es el mismo UUID que auth.users de Supabase.
"""

from datetime import UTC, datetime
from uuid import UUID

from supabase import Client

from ..schemas.perfil import PerfilCreateInternal, PerfilUpdateInternal

TABLE_NAME = "perfiles_usuario"


# ─── EXISTS ───────────────────────────────────────────────────────────────────

def perfil_exists(db: Client, user_id: UUID) -> bool:
    result = (
        db.table(TABLE_NAME)
        .select("id")
        .eq("id", str(user_id))
        .limit(1)
        .execute()
    )
    return len(result.data) > 0


# ─── CREATE ───────────────────────────────────────────────────────────────────

def create_perfil(db: Client, perfil: PerfilCreateInternal) -> dict:
    """
    Crea el perfil público del usuario justo después de que
    Supabase Auth lo registra en auth.users.
    """
    payload = perfil.model_dump()
    # Convertir UUIDs a string para Supabase
    payload["id"] = str(payload["id"])
    payload["empresa_id"] = str(payload["empresa_id"])
    if payload.get("created_by"):
        payload["created_by"] = str(payload["created_by"])

    result = db.table(TABLE_NAME).insert(payload).execute()
    return result.data[0]


# ─── READ ─────────────────────────────────────────────────────────────────────

def get_perfil_by_id(db: Client, user_id: UUID) -> dict | None:
    """Busca el perfil por el UUID de auth.users."""
    result = (
        db.table(TABLE_NAME)
        .select("*")
        .eq("id", str(user_id))
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def get_perfil_by_email(db: Client, email: str) -> dict | None:
    result = (
        db.table(TABLE_NAME)
        .select("*")
        .eq("email", email)
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None


def get_perfiles_by_empresa(
    db: Client,
    empresa_id: UUID,
    page: int = 1,
    items_per_page: int = 20,
    estado: str | None = None,
    rol_global: str | None = None,
) -> dict:
    """Lista todos los perfiles de una empresa con paginación."""
    from ..core.pagination import compute_offset, paginated_response

    offset = compute_offset(page, items_per_page)

    query = (
        db.table(TABLE_NAME)
        .select("*", count="exact")
        .eq("empresa_id", str(empresa_id))
    )

    if estado:
        query = query.eq("estado", estado)
    if rol_global:
        query = query.eq("rol_global", rol_global)

    result = (
        query
        .order("created_at", desc=True)
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

def update_perfil(db: Client, user_id: UUID, update_data: PerfilUpdateInternal) -> dict | None:
    payload = update_data.model_dump(exclude_unset=True, exclude_none=True)
    payload["updated_at"] = datetime.now(UTC).isoformat()

    result = (
        db.table(TABLE_NAME)
        .update(payload)
        .eq("id", str(user_id))
        .execute()
    )
    return result.data[0] if result.data else None


def update_ultimo_acceso(db: Client, user_id: UUID) -> None:
    """Actualiza el timestamp del último acceso. Se llama en cada login."""
    db.table(TABLE_NAME).update(
        {"ultimo_acceso": datetime.now(UTC).isoformat()}
    ).eq("id", str(user_id)).execute()


# ─── SUCURSALES DEL USUARIO ───────────────────────────────────────────────────

def get_sucursales_del_usuario(db: Client, user_id: UUID) -> list[dict]:
    """
    Retorna todas las sucursales a las que tiene acceso el usuario,
    incluyendo su rol en cada una.
    """
    result = (
        db.table("usuarios_sucursales")
        .select("*, sucursales(id, nombre, tipo, estado)")
        .eq("usuario_id", str(user_id))
        .eq("estado", "activo")
        .execute()
    )
    return result.data


def tiene_acceso_sucursal(db: Client, user_id: UUID, sucursal_id: UUID) -> dict | None:
    """
    Verifica si el usuario tiene acceso a una sucursal específica.
    Retorna la asignación completa (con rol_sucursal y permisos) o None.
    """
    result = (
        db.table("usuarios_sucursales")
        .select("*")
        .eq("usuario_id", str(user_id))
        .eq("sucursal_id", str(sucursal_id))
        .eq("estado", "activo")
        .limit(1)
        .execute()
    )
    return result.data[0] if result.data else None