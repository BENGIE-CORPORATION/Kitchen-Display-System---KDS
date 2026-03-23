TABLE_HISTORIAL_PEDIDO = "historial_estados_pedido"
TABLE_HISTORIAL_DETALLE = "historial_estados_detalle"
TABLE_AUDITORIA = "auditoria"

SORTABLE_COLUMNS_HISTORIAL = {"estado_nuevo", "campo_modificado", "created_at"}
SORTABLE_COLUMNS_AUDITORIA = {"modulo", "tabla", "accion", "created_at"}

CAMPOS_MODIFICADOS = {"estado", "estado_pago", "estado_cocina"}

MODULOS_VALIDOS = {
    "ventas", "inventario", "productos", "usuarios",
    "cajas", "clientes", "proveedores", "compras", "sistema",
}

ACCIONES_VALIDAS = {"INSERT", "UPDATE", "DELETE", "LOGIN", "LOGOUT"}