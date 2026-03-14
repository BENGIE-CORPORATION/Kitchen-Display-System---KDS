TABLE_NAME = "proveedores"

SORTABLE_COLUMNS = {
    "nombre_legal",
    "nombre_comercial",
    "codigo",
    "tipo_proveedor",
    "condicion_pago",
    "calificacion",
    "estado",
    "created_at",
}

TIPOS_IDENTIFICACION = {"RUC", "CUIT", "DNI", "Pasaporte"}
TIPOS_PROVEEDOR = {"productos", "servicios", "materias_primas", "mixto"}
CONDICIONES_PAGO = {"contado", "credito_15", "credito_30", "credito_60", "credito_90"}
ESTADOS_VALIDOS = {"activo", "inactivo", "bloqueado"}