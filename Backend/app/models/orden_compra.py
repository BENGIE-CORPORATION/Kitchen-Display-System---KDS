TABLE_NAME = "ordenes_compra"
TABLE_DETALLE = "detalle_ordenes_compra"

SORTABLE_COLUMNS = {
    "numero_orden",
    "fecha_orden",
    "fecha_entrega_esperada",
    "fecha_entrega_real",
    "total",
    "estado",
    "created_at",
}

ESTADOS_VALIDOS = {"borrador", "enviada", "confirmada", "parcial", "recibida", "cancelada"}
CONDICIONES_PAGO = {"contado", "credito_15", "credito_30", "credito_60", "credito_90"}

# Transiciones de estado permitidas
TRANSICIONES_ESTADO = {
    "borrador":   {"enviada", "cancelada"},
    "enviada":    {"confirmada", "cancelada"},
    "confirmada": {"parcial", "recibida", "cancelada"},
    "parcial":    {"recibida", "cancelada"},
    "recibida":   set(),   # estado final
    "cancelada":  set(),   # estado final
}