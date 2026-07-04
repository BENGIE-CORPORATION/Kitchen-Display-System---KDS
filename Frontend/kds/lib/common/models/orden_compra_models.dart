class DetalleOrdenRead {
  final String id;
  final String ordenCompraId;
  final String? materiaPrimaId;
  final String? productoId;
  final double cantidadSolicitada;
  final double cantidadRecibida;
  final String unidadMedida;
  final double precioUnitario;
  final double descuentoPorcentaje;
  final double descuentoMonto;
  final double impuestoPorcentaje;
  final double impuestoMonto;
  final double subtotal;
  final double total;
  final String? notas;

  const DetalleOrdenRead({
    required this.id,
    required this.ordenCompraId,
    this.materiaPrimaId,
    this.productoId,
    required this.cantidadSolicitada,
    required this.cantidadRecibida,
    required this.unidadMedida,
    required this.precioUnitario,
    required this.descuentoPorcentaje,
    required this.descuentoMonto,
    required this.impuestoPorcentaje,
    required this.impuestoMonto,
    required this.subtotal,
    required this.total,
    this.notas,
  });

  factory DetalleOrdenRead.fromJson(Map<String, dynamic> json) =>
      DetalleOrdenRead(
        id: json['id'],
        ordenCompraId: json['orden_compra_id'],
        materiaPrimaId: json['materia_prima_id'],
        productoId: json['producto_id'],
        cantidadSolicitada:
            double.tryParse(json['cantidad_solicitada'].toString()) ?? 0,
        cantidadRecibida:
            double.tryParse(json['cantidad_recibida'].toString()) ?? 0,
        unidadMedida: json['unidad_medida'] ?? '',
        precioUnitario:
            double.tryParse(json['precio_unitario'].toString()) ?? 0,
        descuentoPorcentaje:
            double.tryParse(json['descuento_porcentaje'].toString()) ?? 0,
        descuentoMonto:
            double.tryParse(json['descuento_monto'].toString()) ?? 0,
        impuestoPorcentaje:
            double.tryParse(json['impuesto_porcentaje'].toString()) ?? 0,
        impuestoMonto:
            double.tryParse(json['impuesto_monto'].toString()) ?? 0,
        subtotal: double.tryParse(json['subtotal'].toString()) ?? 0,
        total: double.tryParse(json['total'].toString()) ?? 0,
        notas: json['notas'],
      );

  bool get recibidoCompleto => cantidadRecibida >= cantidadSolicitada;
}

class OrdenCompraRead {
  final String id;
  final String empresaId;
  final String sucursalId;
  final String proveedorId;
  final String numeroOrden;
  final String estado;
  final String? condicionPago;
  final String? notas;
  final double subtotal;
  final double impuestos;
  final double descuentos;
  final double total;
  final DateTime? fechaOrden;
  final DateTime? fechaEntregaEsperada;
  final DateTime? fechaEntregaReal;

  const OrdenCompraRead({
    required this.id,
    required this.empresaId,
    required this.sucursalId,
    required this.proveedorId,
    required this.numeroOrden,
    required this.estado,
    this.condicionPago,
    this.notas,
    required this.subtotal,
    required this.impuestos,
    required this.descuentos,
    required this.total,
    this.fechaOrden,
    this.fechaEntregaEsperada,
    this.fechaEntregaReal,
  });

  factory OrdenCompraRead.fromJson(Map<String, dynamic> json) =>
      OrdenCompraRead(
        id: json['id'],
        empresaId: json['empresa_id'],
        sucursalId: json['sucursal_id'],
        proveedorId: json['proveedor_id'],
        numeroOrden: json['numero_orden'],
        estado: json['estado'] ?? 'borrador',
        condicionPago: json['condicion_pago'],
        notas: json['notas'],
        subtotal: double.tryParse(json['subtotal'].toString()) ?? 0,
        impuestos: double.tryParse(json['impuestos'].toString()) ?? 0,
        descuentos: double.tryParse(json['descuentos'].toString()) ?? 0,
        total: double.tryParse(json['total'].toString()) ?? 0,
        fechaOrden: json['fecha_orden'] != null
            ? DateTime.tryParse(json['fecha_orden'])
            : null,
        fechaEntregaEsperada: json['fecha_entrega_esperada'] != null
            ? DateTime.tryParse(json['fecha_entrega_esperada'])
            : null,
        fechaEntregaReal: json['fecha_entrega_real'] != null
            ? DateTime.tryParse(json['fecha_entrega_real'])
            : null,
      );

  // Transiciones permitidas por estado
  List<String> get transicionesPermitidas {
    const mapa = {
      'borrador':   ['enviada', 'cancelada'],
      'enviada':    ['confirmada', 'cancelada'],
      'confirmada': ['parcial', 'recibida', 'cancelada'],
      'parcial':    ['recibida', 'cancelada'],
      'recibida':   <String>[],
      'cancelada':  <String>[],
    };
    return List<String>.from(mapa[estado] ?? []);
  }

  bool get esEditable => estado == 'borrador';
  bool get esFinal => estado == 'recibida' || estado == 'cancelada';
  bool get puedeRecibirItems =>
      estado == 'confirmada' || estado == 'parcial';

  Map<String, dynamic> toTableRow() => {
        'numeroOrden': numeroOrden,
        'estado': estado,
        'condicionPago': condicionPago ?? '—',
        'total': total,
        'fechaOrden': fechaOrden,
        'fechaEntregaEsperada': fechaEntregaEsperada,
        '_ref': this,
      };
}

class OrdenCompraReadDetalle extends OrdenCompraRead {
  final List<DetalleOrdenRead> items;

  const OrdenCompraReadDetalle({
    required super.id,
    required super.empresaId,
    required super.sucursalId,
    required super.proveedorId,
    required super.numeroOrden,
    required super.estado,
    super.condicionPago,
    super.notas,
    required super.subtotal,
    required super.impuestos,
    required super.descuentos,
    required super.total,
    super.fechaOrden,
    super.fechaEntregaEsperada,
    super.fechaEntregaReal,
    required this.items,
  });

  factory OrdenCompraReadDetalle.fromJson(Map<String, dynamic> json) {
    final base = OrdenCompraRead.fromJson(json);
    final rawItems = (json['items'] as List<dynamic>? ?? []);
    return OrdenCompraReadDetalle(
      id: base.id,
      empresaId: base.empresaId,
      sucursalId: base.sucursalId,
      proveedorId: base.proveedorId,
      numeroOrden: base.numeroOrden,
      estado: base.estado,
      condicionPago: base.condicionPago,
      notas: base.notas,
      subtotal: base.subtotal,
      impuestos: base.impuestos,
      descuentos: base.descuentos,
      total: base.total,
      fechaOrden: base.fechaOrden,
      fechaEntregaEsperada: base.fechaEntregaEsperada,
      fechaEntregaReal: base.fechaEntregaReal,
      items: rawItems
          .map((i) => DetalleOrdenRead.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PaginatedOrdenesCompra {
  final List<OrdenCompraRead> items;
  final int total;
  final int page;
  final int pages;

  const PaginatedOrdenesCompra({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  factory PaginatedOrdenesCompra.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] ?? json['items']) as List<dynamic>;
    return PaginatedOrdenesCompra(
      items: list
          .map((i) => OrdenCompraRead.fromJson(i as Map<String, dynamic>))
          .toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      pages: json['total_pages'] ?? json['pages'] ?? 1,
    );
  }
}