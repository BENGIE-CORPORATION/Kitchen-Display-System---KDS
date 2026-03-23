TABLE_CAJAS = "cajas"
TABLE_SESIONES = "sesiones_caja"
TABLE_MOVIMIENTOS = "movimientos_caja"

SORTABLE_COLUMNS_CAJAS = {"codigo", "nombre", "tipo", "estado", "created_at"}
SORTABLE_COLUMNS_SESIONES = {"numero_sesion", "fecha_apertura", "fecha_cierre", "total_ventas", "estado", "created_at"}
SORTABLE_COLUMNS_MOVIMIENTOS = {"concepto", "monto", "tipo", "created_at"}

TIPOS_CAJA = {"principal", "secundaria", "express"}
ESTADOS_CAJA = {"activo", "inactivo", "mantenimiento"}
ESTADOS_SESION = {"abierta", "cerrada", "auditada"}
TIPOS_MOVIMIENTO = {"entrada", "salida"}
METODOS_PAGO = {"efectivo", "tarjeta_debito", "tarjeta_credito", "transferencia", "sinpe", "otros"}