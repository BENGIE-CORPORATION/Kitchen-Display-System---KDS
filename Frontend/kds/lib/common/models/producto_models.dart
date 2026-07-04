class ProductoRead {
  final String id;
  final String empresaId;
  final String nombre;
  final String categoriaId;
  final String tipoProducto;
  final String unidadMedida;
  final String? codigoInterno;
  final String? codigoBarras;
  final String? descripcion;
  final String? descripcionCorta;
  final String? marca;
  final String? imagenPrincipalUrl;
  final bool esVendible;
  final bool esComprable;
  final bool requiereInventario;
  final bool permiteDecimal;
  final String estado;

  const ProductoRead({
    required this.id,
    required this.empresaId,
    required this.nombre,
    required this.categoriaId,
    required this.tipoProducto,
    required this.unidadMedida,
    this.codigoInterno,
    this.codigoBarras,
    this.descripcion,
    this.descripcionCorta,
    this.marca,
    this.imagenPrincipalUrl,
    required this.esVendible,
    required this.esComprable,
    required this.requiereInventario,
    required this.permiteDecimal,
    required this.estado,
  });

  factory ProductoRead.fromJson(Map<String, dynamic> json) => ProductoRead(
        id: json['id'],
        empresaId: json['empresa_id'],
        nombre: json['nombre'],
        categoriaId: json['categoria_id'],
        tipoProducto: json['tipo_producto'] ?? 'simple',
        unidadMedida: json['unidad_medida'] ?? 'unidad',
        codigoInterno: json['codigo_interno'],
        codigoBarras: json['codigo_barras'],
        descripcion: json['descripcion'],
        descripcionCorta: json['descripcion_corta'],
        marca: json['marca'],
        imagenPrincipalUrl: json['imagen_principal_url'],
        esVendible: json['es_vendible'] ?? true,
        esComprable: json['es_comprable'] ?? true,
        requiereInventario: json['requiere_inventario'] ?? true,
        permiteDecimal: json['permite_decimal'] ?? false,
        estado: json['estado'] ?? 'activo',
      );
}

// ProductoSucursalRead incluye precio e IVA — es el que se usa en el POS
class ProductoSucursalRead {
  final String id;
  final String productoId;
  final String sucursalId;
  final double precioVenta;
  final double? precioCosto;
  final bool aplicaIva;
  final bool aplicaServicio;
  final double porcentajeIva;
  final double porcentajeServicio;
  final double stockDisponible;
  final double stockMinimo;
  final bool disponibleVenta;

  // Campos del join con productos
  final String? nombre;
  final String? unidadMedida;
  final String? codigoInterno;
  final String? descripcionCorta;
  final String? imagenPrincipalUrl;
  final bool permiteDecimal;

  const ProductoSucursalRead({
    required this.id,
    required this.productoId,
    required this.sucursalId,
    required this.precioVenta,
    this.precioCosto,
    required this.aplicaIva,
    required this.aplicaServicio,
    required this.porcentajeIva,
    required this.porcentajeServicio,
    required this.stockDisponible,
    required this.stockMinimo,
    required this.disponibleVenta,
    this.nombre,
    this.unidadMedida,
    this.codigoInterno,
    this.descripcionCorta,
    this.imagenPrincipalUrl,
    this.permiteDecimal = false,
  });

  // Precio final con IVA y servicio calculados
  double get precioConIva =>
      precioVenta * (1 + porcentajeIva / 100);

  double get montoIva => precioVenta * (porcentajeIva / 100);
  double get montoServicio => precioVenta * (porcentajeServicio / 100);
  double get precioTotal =>
      precioVenta + (aplicaIva ? montoIva : 0) + (aplicaServicio ? montoServicio : 0);

  factory ProductoSucursalRead.fromJson(Map<String, dynamic> json) {
    // El endpoint /productos/sucursal/{id} hace join con productos
    final p = json['productos'] as Map<String, dynamic>? ?? {};

    return ProductoSucursalRead(
      id: json['id'],
      productoId: json['producto_id'],
      sucursalId: json['sucursal_id'],
      precioVenta: double.tryParse(json['precio_venta'].toString()) ?? 0,
      precioCosto: json['precio_costo'] != null
          ? double.tryParse(json['precio_costo'].toString())
          : null,
      aplicaIva: json['aplica_iva'] ?? true,
      aplicaServicio: json['aplica_servicio'] ?? true,
      porcentajeIva:
          double.tryParse(json['porcentaje_iva'].toString()) ?? 13.0,
      porcentajeServicio:
          double.tryParse(json['porcentaje_servicio'].toString()) ?? 10.0,
      stockDisponible:
          double.tryParse(json['stock_disponible'].toString()) ?? 0,
      stockMinimo:
          double.tryParse(json['stock_minimo'].toString()) ?? 0,
      disponibleVenta: json['disponible_venta'] ?? true,
      nombre: p['nombre'] as String?,
      unidadMedida: p['unidad_medida'] as String?,
      codigoInterno: p['codigo_interno'] as String?,
      descripcionCorta: p['descripcion_corta'] as String?,
      imagenPrincipalUrl: p['imagen_principal_url'] as String?,
      permiteDecimal: p['permite_decimal'] as bool? ?? false,
    );
  }
}

class CategoriaRead {
  final String id;
  final String empresaId;
  final String nombre;
  final String tipo;
  final String? codigo;
  final String? descripcion;
  final int orden;
  final String estado;

  const CategoriaRead({
    required this.id,
    required this.empresaId,
    required this.nombre,
    required this.tipo,
    this.codigo,
    this.descripcion,
    required this.orden,
    required this.estado,
  });

  factory CategoriaRead.fromJson(Map<String, dynamic> json) => CategoriaRead(
        id: json['id'],
        empresaId: json['empresa_id'],
        nombre: json['nombre'],
        tipo: json['tipo'] ?? 'alimento',
        codigo: json['codigo'],
        descripcion: json['descripcion'],
        orden: json['orden'] ?? 0,
        estado: json['estado'] ?? 'activo',
      );
}

class PaginatedProductosSucursal {
  final List<ProductoSucursalRead> items;
  final int total;

  const PaginatedProductosSucursal({
    required this.items,
    required this.total,
  });

  factory PaginatedProductosSucursal.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] ?? json['items']) as List<dynamic>;
    return PaginatedProductosSucursal(
      items: list
          .map((i) =>
              ProductoSucursalRead.fromJson(i as Map<String, dynamic>))
          .toList(),
      total: json['total'] ?? 0,
    );
  }
}