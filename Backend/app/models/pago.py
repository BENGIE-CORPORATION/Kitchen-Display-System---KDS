TABLE_PAGOS = "pagos"
TABLE_DIVISIONES = "divisiones_cuenta"
TABLE_DETALLE_DIVISIONES = "detalle_divisiones"

SORTABLE_COLUMNS_PAGOS = {"numero_pago", "metodo_pago", "monto", "estado", "created_at"}
SORTABLE_COLUMNS_DIVISIONES = {"numero_division", "tipo_division", "monto", "estado", "created_at"}

METODOS_PAGO = {
    "efectivo", "tarjeta_debito", "tarjeta_credito",
    "transferencia", "sinpe", "cheque", "credito", "otros",
}
TIPOS_TARJETA = {"visa", "mastercard", "amex"}
ESTADOS_PAGO = {"completado", "pendiente", "rechazado", "reversado"}
TIPOS_DIVISION = {"por_monto", "por_porcentaje", "por_productos", "por_persona"}
ESTADOS_DIVISION = {"pendiente", "pagado"}