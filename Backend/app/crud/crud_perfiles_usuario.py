"""
CRUD de Perfiles de Usuario.
Tabla: public.perfiles_usuario

Reglas de sincronización críticas:
────────────────────────────────────
1. CREATE: El perfil SIEMPRE se crea DESPUÉS de auth.users.
   Si falla el INSERT del perfil → hacer rollback borrando el usuario de auth.
   Un usuario en auth sin perfil = limbo (puede hacer login pero tu app lo rechaza).

2. DELETE: Nunca borrar físicamente. Soft delete = estado "inactivo".
   Si se desactiva un perfil → también desactivar sus asignaciones en usuarios_sucursales.

3. EMPRESA: empresa_id no se puede cambiar por PATCH normal.
   Solo super_admin puede mover un usuario a otra empresa.

4. ROL: rol_global no lo puede cambiar el propio usuario.
   Solo super_admin puede cambiar roles.
"""

from datetime import UTC, datetime
from uuid import UUID

from supabase import Client

from ..core.pagination import compute_offset, paginated_response
from ..models.perfil import TABLE_NAME
from ..schemas.perfil import PerfilCreateInternal, PerfilUpdateInternal


def _now() -> str:
    return datetime.now(UTC).isoformat()


# ─── EXISTS ───────────────────────────────────────────────────────────────────

def perfil_exists(db: Client, user_id: UUID) -> bool:
    result = (
        db.table(TABLE_NAME).select("id")
        .eq("id", str(user_id)).limit(1).execute()
    )
    return len(result.data) > 0


def perfil_email_exists(db: Client, email: str, exclude_id: UUID | None = None) -> bool:
    query = db.table(TABLE_NAME).select("id").eq("email", email)
    if exclude_id:
        query = query.neq("id", str(exclude_id))
    result = query.limit(1).execute()
    return len(result.data) > 0


# ─── CREATE ──────────────────────────────────────────────────────────────────
# ⚠️ NUNCA llamar esto sin haber creado primero el usuario en auth.users

def create_perfil(db: Client, perfil: PerfilCreateInternal) -> dict:
    """
    Crea el perfil en perfiles_usuario.
    PRECONDICIÓN: el usuario YA existe en auth.users con el mismo UUID.
    Si este INSERT falla, el caller debe hacer rollback en auth.
    """
    payload = perfil.model_dump()
    for field in ("id", "empresa_id", "created_by"):
        if payload.get(field):
            payload[field] = str(payload[field])

    result = db.table(TABLE_NAME).insert(payload).execute()
    return result.data[0]


# ─── READ ─────────────────────────────────────────────────────────────────────

def get_perfil_by_id(db: Client, user_id: UUID) -> dict | None:
    result = (
        db.table(TABLE_NAME).select("*")
        .eq("id", str(user_id)).limit(1).execute()
    )
    return result.data[0] if result.data else None


def get_perfil_by_email(db: Client, email: str) -> dict | None:
    result = (
        db.table(TABLE_NAME).select("*")
        .eq("email", email).limit(1).execute()
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
    offset = compute_offset(page, items_per_page)

    query = (
        db.table(TABLE_NAME).select("*", count="exact")
        .eq("empresa_id", str(empresa_id))
        .neq("estado", "inactivo")
    )
    if estado:
        query = query.eq("estado", estado)
    if rol_global:
        query = query.eq("rol_global", rol_global)

    result = (
        query.order("created_at", desc=True)
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

def update_perfil(db: Client, user_id: UUID, data: PerfilUpdateInternal) -> dict | None:
    payload = data.model_dump(exclude_unset=True, exclude_none=True)
    payload["updated_at"] = _now()

    for field in ("updated_by",):
        if payload.get(field):
            payload[field] = str(payload[field])

    result = (
        db.table(TABLE_NAME).update(payload)
        .eq("id", str(user_id)).execute()
    )
    return result.data[0] if result.data else None


def update_ultimo_acceso(db: Client, user_id: UUID) -> None:
    """Llamar en cada login exitoso. No lanzar error si falla — no es crítico."""
    try:
        db.table(TABLE_NAME).update(
            {"ultimo_acceso": _now()}
        ).eq("id", str(user_id)).execute()
    except Exception:
        pass  # No es crítico, no rompemos el login por esto


def cambiar_rol(db: Client, user_id: UUID, nuevo_rol: str) -> dict | None:
    """Solo super_admin puede llamar esto. Cambia el rol_global del usuario."""
    result = (
        db.table(TABLE_NAME)
        .update({"rol_global": nuevo_rol, "updated_at": _now()})
        .eq("id", str(user_id)).execute()
    )
    return result.data[0] if result.data else None


def cambiar_estado(db: Client, user_id: UUID, nuevo_estado: str) -> dict | None:
    """Suspender o reactivar un usuario."""
    result = (
        db.table(TABLE_NAME)
        .update({"estado": nuevo_estado, "updated_at": _now()})
        .eq("id", str(user_id)).execute()
    )
    return result.data[0] if result.data else None


# ─── SOFT DELETE ─────────────────────────────────────────────────────────────
# ⚠️ SINCRONIZACIÓN CRÍTICA

def soft_delete_perfil(db: Client, db_admin: Client, user_id: UUID) -> dict | None:
    """
    Soft delete de perfil.

    SINCRONIZACIÓN en 3 pasos:
    1. Marcar perfil como inactivo en perfiles_usuario
    2. Desactivar TODAS sus asignaciones en usuarios_sucursales
    3. Revocar sesiones activas en Supabase Auth (logout forzado)

    Si el paso 3 falla, el usuario no podrá hacer nuevas acciones porque
    get_current_user verificará estado == "activo" antes de continuar.
    """
    now = _now()

    # 1. Desactivar perfil
    result = (
        db.table(TABLE_NAME)
        .update({"estado": "inactivo", "updated_at": now})
        .eq("id", str(user_id)).execute()
    )

    # 2. SINCRONIZACIÓN: desactivar asignaciones a sucursales
    try:
        db.table("usuarios_sucursales").update(
            {"estado": "inactivo", "updated_at": now}
        ).eq("usuario_id", str(user_id)).eq("estado", "activo").execute()
    except Exception as e:
        print(f"[CRÍTICO] Perfil {user_id} desactivado pero asignaciones NO. Error: {e}")

    # 3. SINCRONIZACIÓN: revocar sesiones en Supabase Auth (forzar logout)
    try:
        db_admin.auth.admin.sign_out(str(user_id), scope="global")
    except Exception as e:
        # No crítico — el usuario igual será rechazado por estado inactivo
        print(f"[WARN] No se pudieron revocar sesiones de {user_id}. Error: {e}")

    return result.data[0] if result.data else None


def hard_delete_perfil(db: Client, db_admin: Client, user_id: UUID) -> bool:
    """
    Hard delete completo.

    SINCRONIZACIÓN en 3 pasos:
    1. Eliminar asignaciones en usuarios_sucursales
    2. Eliminar perfil en perfiles_usuario
    3. Eliminar usuario en auth.users (usando service_role)

    Si el paso 3 falla: el usuario no puede hacer login (perfil no existe)
    pero sí existe en auth. Hay que limpiarlo manualmente o reintentar.
    """
    # 1. Eliminar asignaciones
    db.table("usuarios_sucursales").delete().eq("usuario_id", str(user_id)).execute()

    # 2. Eliminar perfil
    db.table(TABLE_NAME).delete().eq("id", str(user_id)).execute()

    # 3. Eliminar de auth.users
    try:
        db_admin.auth.admin.delete_user(str(user_id))
        return True
    except Exception as e:
        print(f"[CRÍTICO] Perfil {user_id} borrado de BD pero NO de auth.users. Error: {e}")
        return False


# ─── SUCURSALES DEL USUARIO ───────────────────────────────────────────────────

def get_sucursales_del_usuario(db: Client, user_id: UUID) -> list[dict]:
    result = (
        db.table("usuarios_sucursales")
        .select("*, sucursales(id, nombre, tipo, estado, ciudad)")
        .eq("usuario_id", str(user_id))
        .eq("estado", "activo")
        .execute()
    )
    return result.data


def tiene_acceso_sucursal(db: Client, user_id: UUID, sucursal_id: UUID) -> dict | None:
    result = (
        db.table("usuarios_sucursales").select("*")
        .eq("usuario_id", str(user_id))
        .eq("sucursal_id", str(sucursal_id))
        .eq("estado", "activo")
        .limit(1).execute()
    )
    return result.data[0] if result.data else None
