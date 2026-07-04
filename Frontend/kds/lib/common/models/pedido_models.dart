class DetallePedidoRead {
  final String id;
  final String pedidoId;
  final String productoId;
  final double cantidad;
  final String unidadMedida;
  final double precioUnitario;
  final double descuentoPorcentaje;
  final double descuentoMonto;
  final double subtotal;
  final double iva;
  final double servicio;
  final double total;
  final double? costoUnitario;
  final double? costoTotal;
  final double? utilidad;
  final String estado;
  final String? motivoCancelacion;
  final Map<String, dynamic>? variantesSeleccionadas;
  final String? notas;
  final DateTime? createdAt;

  const DetallePedidoRead({
    required this.id,
    required this.pedidoId,
    required this.productoId,
    required this.cantidad,
    required this.unidadMedida,
    required this.precioUnitario,
    required this.descuentoPorcentaje,
    required this.descuentoMonto,
    required this.subtotal,
    required this.iva,
    required this.servicio,
    required this.total,
    this.costoUnitario,
    this.costoTotal,
    this.utilidad,
    required this.estado,
    this.motivoCancelacion,
    this.variantesSeleccionadas,
    this.notas,
    this.createdAt,
  });

  bool get cancelado => estado == 'cancelado';

  factory DetallePedidoRead.fromJson(Map<String, dynamic> json) =>
      DetallePedidoRead(
        id: json['id'],
        pedidoId: json['pedido_id'],
        productoId: json['producto_id'],
        cantidad: double.tryParse(json['cantidad'].toString()) ?? 0,
        unidadMedida: json['unidad_medida'] ?? 'unidad',
        precioUnitario:
            double.tryParse(json['precio_unitario'].toString()) ?? 0,
        descuentoPorcentaje:
            double.tryParse(json['descuento_porcentaje'].toString()) ?? 0,
        descuentoMonto:
            double.tryParse(json['descuento_monto'].toString()) ?? 0,
        subtotal: double.tryParse(json['subtotal'].toString()) ?? 0,
        iva: double.tryParse(json['iva'].toString()) ?? 0,
        servicio: double.tryParse(json['servicio'].toString()) ?? 0,
        total: double.tryParse(json['total'].toString()) ?? 0,
        costoUnitario: json['costo_unitario'] != null
            ? double.tryParse(json['costo_unitario'].toString())
            : null,
        costoTotal: json['costo_total'] != null
            ? double.tryParse(json['costo_total'].toString())
            : null,
        utilidad: json['utilidad'] != null
            ? double.tryParse(json['utilidad'].toString())
            : null,
        estado: json['estado'] ?? 'pendiente',
        motivoCancelacion: json['motivo_cancelacion'],
        variantesSeleccionadas:
            json['variantes_seleccionadas'] as Map<String, dynamic>?,
        notas: json['notas'],
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'])
            : null,
      );
}

class PedidoRead {
  final String id;
  final String empresaId;
  final String sucursalId;
  final String numeroPedido;
  final String tipoPedido;
  final String tipoVenta;
  final String canalVenta;
  final String estado;
  final String estadoPago;
  final String? estadoCocina;
  final String prioridad;
  final String? mesaId;
  final String? clienteId;
  final String? nombreCliente;
  final String? telefonoCliente;
  final String? direccionEntrega;
  final int? cantidadComensales;
  final String? meseroId;
  final int? tiempoEstimadoMinutos;
  final double subtotal;
  final double descuentoPorcentaje;
  final double descuentoMonto;
  final double totalIva;
  final double totalServicio;
  final double propina;
  final double total;
  final String? sesionCajaId;
  final String? motivoCancelacion;
  final String? numeroFactura;
  final DateTime? fechaPedido;
  final DateTime? fechaFacturacion;
  final DateTime? fechaEntrega;

  const PedidoRead({
    required this.id,
    required this.empresaId,
    required this.sucursalId,
    required this.numeroPedido,
    required this.tipoPedido,
    required this.tipoVenta,
    required this.canalVenta,
    required this.estado,
    required this.estadoPago,
    this.estadoCocina,
    required this.prioridad,
    this.mesaId,
    this.clienteId,
    this.nombreCliente,
    this.telefonoCliente,
    this.direccionEntrega,
    this.cantidadComensales,
    this.meseroId,
    this.tiempoEstimadoMinutos,
    required this.subtotal,
    required this.descuentoPorcentaje,
    required this.descuentoMonto,
    required this.totalIva,
    required this.totalServicio,
    required this.propina,
    required this.total,
    this.sesionCajaId,
    this.motivoCancelacion,
    this.numeroFactura,
    this.fechaPedido,
    this.fechaFacturacion,
    this.fechaEntrega,
  });

  bool get esEditable => estado == 'borrador' || estado == 'abierto';
  bool get esFinal => estado == 'facturado' || estado == 'cancelado';
  bool get puedeFacturar =>
      estado == 'listo' || estado == 'entregado' || estado == 'en_entrega';
  bool get estaPagado => estadoPago == 'pagado';

  List<String> get transicionesPermitidas {
    const mapa = {
      'borrador': ['abierto', 'cancelado'],
      'abierto': ['en_preparacion', 'listo', 'cancelado'],
      'en_preparacion': ['listo', 'cancelado'],
      'listo': ['en_entrega', 'entregado', 'facturado'],
      'en_entrega': ['entregado'],
      'entregado': ['facturado'],
      'facturado': <String>[],
      'cancelado': <String>[],
    };
    return List<String>.from(mapa[estado] ?? []);
  }

  factory PedidoRead.fromJson(Map<String, dynamic> json) => PedidoRead(
        id: json['id'],
        empresaId: json['empresa_id'],
        sucursalId: json['sucursal_id'],
        numeroPedido: json['numero_pedido'],
        tipoPedido: json['tipo_pedido'] ?? 'mesa',
        tipoVenta: json['tipo_venta'] ?? 'contado',
        canalVenta: json['canal_venta'] ?? 'presencial',
        estado: json['estado'] ?? 'borrador',
        estadoPago: json['estado_pago'] ?? 'pendiente',
        estadoCocina: json['estado_cocina'],
        prioridad: json['prioridad'] ?? 'normal',
        mesaId: json['mesa_id'],
        clienteId: json['cliente_id'],
        nombreCliente: json['nombre_cliente'],
        telefonoCliente: json['telefono_cliente'],
        direccionEntrega: json['direccion_entrega'],
        cantidadComensales: json['cantidad_comensales'],
        meseroId: json['mesero_id'],
        tiempoEstimadoMinutos: json['tiempo_estimado_minutos'],
        subtotal: double.tryParse(json['subtotal'].toString()) ?? 0,
        descuentoPorcentaje:
            double.tryParse(json['descuento_porcentaje'].toString()) ?? 0,
        descuentoMonto:
            double.tryParse(json['descuento_monto'].toString()) ?? 0,
        totalIva: double.tryParse(json['total_iva'].toString()) ?? 0,
        totalServicio:
            double.tryParse(json['total_servicio'].toString()) ?? 0,
        propina: double.tryParse(json['propina'].toString()) ?? 0,
        total: double.tryParse(json['total'].toString()) ?? 0,
        sesionCajaId: json['sesion_caja_id'],
        motivoCancelacion: json['motivo_cancelacion'],
        numeroFactura: json['numero_factura'],
        fechaPedido: json['fecha_pedido'] != null
            ? DateTime.tryParse(json['fecha_pedido'])
            : null,
        fechaFacturacion: json['fecha_facturacion'] != null
            ? DateTime.tryParse(json['fecha_facturacion'])
            : null,
        fechaEntrega: json['fecha_entrega'] != null
            ? DateTime.tryParse(json['fecha_entrega'])
            : null,
      );

  Map<String, dynamic> toTableRow() => {
        'numeroPedido': numeroPedido,
        'tipoPedido': tipoPedido,
        'estado': estado,
        'estadoPago': estadoPago,
        'total': total,
        'fechaPedido': fechaPedido,
        'nombreCliente': nombreCliente ?? '—',
        '_ref': this,
      };
}

class PedidoReadDetalle extends PedidoRead {
  final List<DetallePedidoRead> items;

  const PedidoReadDetalle({
    required super.id,
    required super.empresaId,
    required super.sucursalId,
    required super.numeroPedido,
    required super.tipoPedido,
    required super.tipoVenta,
    required super.canalVenta,
    required super.estado,
    required super.estadoPago,
    super.estadoCocina,
    required super.prioridad,
    super.mesaId,
    super.clienteId,
    super.nombreCliente,
    super.telefonoCliente,
    super.direccionEntrega,
    super.cantidadComensales,
    super.meseroId,
    super.tiempoEstimadoMinutos,
    required super.subtotal,
    required super.descuentoPorcentaje,
    required super.descuentoMonto,
    required super.totalIva,
    required super.totalServicio,
    required super.propina,
    required super.total,
    super.sesionCajaId,
    super.motivoCancelacion,
    super.numeroFactura,
    super.fechaPedido,
    super.fechaFacturacion,
    super.fechaEntrega,
    required this.items,
  });

  factory PedidoReadDetalle.fromJson(Map<String, dynamic> json) {
    final base = PedidoRead.fromJson(json);
    return PedidoReadDetalle(
      id: base.id,
      empresaId: base.empresaId,
      sucursalId: base.sucursalId,
      numeroPedido: base.numeroPedido,
      tipoPedido: base.tipoPedido,
      tipoVenta: base.tipoVenta,
      canalVenta: base.canalVenta,
      estado: base.estado,
      estadoPago: base.estadoPago,
      estadoCocina: base.estadoCocina,
      prioridad: base.prioridad,
      mesaId: base.mesaId,
      clienteId: base.clienteId,
      nombreCliente: base.nombreCliente,
      telefonoCliente: base.telefonoCliente,
      direccionEntrega: base.direccionEntrega,
      cantidadComensales: base.cantidadComensales,
      meseroId: base.meseroId,
      tiempoEstimadoMinutos: base.tiempoEstimadoMinutos,
      subtotal: base.subtotal,
      descuentoPorcentaje: base.descuentoPorcentaje,
      descuentoMonto: base.descuentoMonto,
      totalIva: base.totalIva,
      totalServicio: base.totalServicio,
      propina: base.propina,
      total: base.total,
      sesionCajaId: base.sesionCajaId,
      motivoCancelacion: base.motivoCancelacion,
      numeroFactura: base.numeroFactura,
      fechaPedido: base.fechaPedido,
      fechaFacturacion: base.fechaFacturacion,
      fechaEntrega: base.fechaEntrega,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((i) =>
              DetallePedidoRead.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PaginatedPedidos {
  final List<PedidoRead> items;
  final int total;
  final int page;
  final int pages;

  const PaginatedPedidos({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  factory PaginatedPedidos.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] ?? json['items']) as List<dynamic>;
    return PaginatedPedidos(
      items: list
          .map((i) => PedidoRead.fromJson(i as Map<String, dynamic>))
          .toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      pages: json['total_pages'] ?? json['pages'] ?? 1,
    );
  }
}