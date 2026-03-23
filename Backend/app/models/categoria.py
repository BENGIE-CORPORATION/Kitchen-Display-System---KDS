TABLE_NAME = "categorias"

SORTABLE_COLUMNS = {
    "nombre",
    "codigo",
    "tipo",
    "orden",
    "estado",
    "created_at",
}

FILTERABLE_COLUMNS = {
    "tipo",
    "estado",
    "empresa_id",
    "categoria_padre_id",
}

TIPOS_VALIDOS = {"alimento", "bebida", "producto", "servicio"}
ESTADOS_VALIDOS = {"activo", "inactivo"}