TABLE_NAME = "clientes"

SORTABLE_COLUMNS = {
    "nombre", "apellido", "nombre_comercial", "tipo_cliente",
    "total_compras", "cantidad_compras", "puntos_fidelidad",
    "ultima_compra", "fecha_registro", "estado", "created_at",
}

TIPOS_CLIENTE = {"final", "frecuente", "corporativo", "mayorista"}
TIPOS_IDENTIFICACION = {"DNI", "RUC", "Pasaporte", "Cedula"}
GENEROS = {"M", "F", "Otro", "No especifica"}
ESTADOS_VALIDOS = {"activo", "inactivo", "bloqueado"}