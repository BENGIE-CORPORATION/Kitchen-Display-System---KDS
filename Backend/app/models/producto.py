TABLE_NAME = "productos"
TABLE_SUCURSALES = "productos_sucursales"

SORTABLE_COLUMNS = {
    "nombre",
    "codigo_interno",
    "marca",
    "tipo_producto",
    "estado",
    "created_at",
}

TIPOS_PRODUCTO = {"simple", "compuesto", "servicio", "combo"}
UNIDADES_MEDIDA = {"unidad", "kg", "g", "l", "ml", "m", "pack"}
ESTADOS_VALIDOS = {"activo", "inactivo", "descontinuado"}