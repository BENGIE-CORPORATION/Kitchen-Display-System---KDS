TABLE_NAME = "materias_primas"
TABLE_SUCURSALES = "materias_primas_sucursales"

SORTABLE_COLUMNS = {
    "nombre",
    "codigo",
    "categoria",
    "unidad_medida",
    "estado",
    "created_at",
}

UNIDADES_MEDIDA = {"kg", "g", "l", "ml", "unidades", "m", "m2", "m3"}
ESTADOS_VALIDOS = {"activo", "inactivo"}