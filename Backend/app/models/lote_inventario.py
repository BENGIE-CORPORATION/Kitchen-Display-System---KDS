TABLE_NAME = "lotes_inventario"

SORTABLE_COLUMNS = {
    "numero_lote",
    "fecha_ingreso",
    "fecha_vencimiento",
    "cantidad_actual",
    "estado",
    "created_at",
}

ESTADOS_VALIDOS = {"activo", "vencido", "agotado"}