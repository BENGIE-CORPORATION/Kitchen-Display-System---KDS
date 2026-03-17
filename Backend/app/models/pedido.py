TABLE_NAME = "pedidos"
TABLE_DETALLE = "detalle_pedidos"

SORTABLE_COLUMNS = {
    "numero_pedido", "fecha_pedido", "total", "estado",
    "estado_pago", "prioridad", "tipo_pedido", "created_at",
}

TIPOS_PEDIDO = {"mesa", "para_llevar", "domicilio", "mostrador"}
TIPOS_VENTA = {"contado", "credito"}
CANALES_VENTA = {"presencial", "telefono", "web", "app", "whatsapp"}
PRIORIDADES = {"baja", "normal", "alta", "urgente"}

ESTADOS_PEDIDO = {
    "borrador", "abierto", "en_preparacion",
    "listo", "en_entrega", "entregado", "facturado", "cancelado",
}
ESTADOS_PAGO = {"pendiente", "pagado", "pago_parcial", "credito"}
ESTADOS_COCINA = {"pendiente", "en_preparacion", "listo", "entregado"}
ESTADOS_DETALLE = {"pendiente", "en_preparacion", "listo", "entregado", "cancelado"}

# Transiciones permitidas para el pedido
TRANSICIONES_PEDIDO = {
    "borrador":       {"abierto", "cancelado"},
    "abierto":        {"en_preparacion", "listo", "cancelado"},
    "en_preparacion": {"listo", "cancelado"},
    "listo":          {"en_entrega", "entregado", "facturado"},
    "en_entrega":     {"entregado"},
    "entregado":      {"facturado"},
    "facturado":      set(),   # estado final
    "cancelado":      set(),   # estado final
}