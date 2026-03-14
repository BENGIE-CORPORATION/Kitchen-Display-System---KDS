TABLE_NAME = "movimientos_inventario"
TABLE_DETALLE = "detalle_movimientos_inventario"

SORTABLE_COLUMNS = {
    "numero_movimiento",
    "fecha_movimiento",
    "tipo_movimiento",
    "total_costo",
    "estado",
    "created_at",
}

TIPOS_MOVIMIENTO = {
    "entrada_compra",
    "entrada_devolucion",
    "entrada_ajuste",
    "entrada_transferencia",
    "salida_venta",
    "salida_merma",
    "salida_devolucion",
    "salida_transferencia",
    "ajuste_inventario",
}

# Tipos que requieren motivo obligatorio
TIPOS_REQUIEREN_MOTIVO = {"entrada_ajuste", "salida_merma", "ajuste_inventario"}

# Tipos que requieren sucursal origen y destino
TIPOS_TRANSFERENCIA = {"entrada_transferencia", "salida_transferencia"}

ESTADOS_VALIDOS = {"borrador", "completado", "cancelado"}

TIPOS_ENTRADA = {
    "entrada_compra", "entrada_devolucion",
    "entrada_ajuste", "entrada_transferencia",
}
TIPOS_SALIDA = {
    "salida_venta", "salida_merma",
    "salida_devolucion", "salida_transferencia",
}