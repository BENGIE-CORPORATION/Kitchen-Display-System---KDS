TABLE_NAME = "perfiles_usuario"

SORTABLE_COLUMNS = {
    "nombre_completo", "email", "rol_global", "estado",
    "ultimo_acceso", "created_at",
}

ROLES_GLOBALES = {"super_admin", "admin_empresa", "empleado"}
ESTADOS_VALIDOS = {"activo", "inactivo", "suspendido"}