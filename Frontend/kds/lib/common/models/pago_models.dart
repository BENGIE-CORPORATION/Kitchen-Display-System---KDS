class PagoRead {
  final String id;
  final String pedidoId;
  final String sesionCajaId;
  final String metodoPago;
  final double monto;
  final String numeroPago;
  final double? montoRecibido;
  final double? cambio;
  final String? referencia;
  final String? ultimos4Digitos;
  final String? tipoTarjeta;
  final String estado;
  final DateTime? createdAt;

  const PagoRead({
    required this.id,
    required this.pedidoId,
    required this.sesionCajaId,
    required this.metodoPago,
    required this.monto,
    required this.numeroPago,
    this.montoRecibido,
    this.cambio,
    this.referencia,
    this.ultimos4Digitos,
    this.tipoTarjeta,
    required this.estado,
    this.createdAt,
  });

  factory PagoRead.fromJson(Map<String, dynamic> json) => PagoRead(
        id: json['id'],
        pedidoId: json['pedido_id'],
        sesionCajaId: json['sesion_caja_id'],
        metodoPago: json['metodo_pago'],
        monto: double.tryParse(json['monto'].toString()) ?? 0,
        numeroPago: json['numero_pago'],
        montoRecibido: json['monto_recibido'] != null
            ? double.tryParse(json['monto_recibido'].toString())
            : null,
        cambio: json['cambio'] != null
            ? double.tryParse(json['cambio'].toString())
            : null,
        referencia: json['referencia'],
        ultimos4Digitos: json['ultimos_4_digitos'],
        tipoTarjeta: json['tipo_tarjeta'],
        estado: json['estado'] ?? 'completado',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'])
            : null,
      );
}

class ResumenPagos {
  final double totalPagado;
  final double totalPendiente;
  final Map<String, double> porMetodo;

  const ResumenPagos({
    required this.totalPagado,
    required this.totalPendiente,
    required this.porMetodo,
  });

  factory ResumenPagos.fromJson(Map<String, dynamic> json) => ResumenPagos(
        totalPagado:
            double.tryParse(json['total_pagado']?.toString() ?? '0') ?? 0,
        totalPendiente:
            double.tryParse(json['total_pendiente']?.toString() ?? '0') ?? 0,
        porMetodo: (json['por_metodo'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, double.tryParse(v.toString()) ?? 0)),
      );
}