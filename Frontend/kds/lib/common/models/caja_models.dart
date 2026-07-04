class CajaRead {
  final String id;
  final String sucursalId;
  final String codigo;
  final String nombre;
  final String tipo;
  final String? descripcion;
  final String? numeroSerieFiscal;
  final String estado;

  const CajaRead({
    required this.id,
    required this.sucursalId,
    required this.codigo,
    required this.nombre,
    required this.tipo,
    this.descripcion,
    this.numeroSerieFiscal,
    required this.estado,
  });

  bool get activa => estado == 'activo';

  factory CajaRead.fromJson(Map<String, dynamic> json) => CajaRead(
        id: json['id'],
        sucursalId: json['sucursal_id'],
        codigo: json['codigo'],
        nombre: json['nombre'],
        tipo: json['tipo'] ?? 'principal',
        descripcion: json['descripcion'],
        numeroSerieFiscal: json['numero_serie_fiscal'],
        estado: json['estado'] ?? 'activo',
      );
}

class SesionCajaRead {
  final String id;
  final String cajaId;
  final String usuarioId;
  final String numeroSesion;
  final double montoApertura;
  final double? montoCierre;
  final double? montoEsperado;
  final double? diferencia;
  final double totalVentas;
  final double totalEfectivo;
  final double totalTarjetaDebito;
  final double totalTarjetaCredito;
  final double totalTransferencia;
  final double totalSinpe;
  final double totalOtros;
  final double totalEntradas;
  final double totalSalidas;
  final int cantidadTransacciones;
  final String estado;
  final DateTime? fechaApertura;
  final DateTime? fechaCierre;
  final String? notasApertura;
  final String? notasCierre;

  const SesionCajaRead({
    required this.id,
    required this.cajaId,
    required this.usuarioId,
    required this.numeroSesion,
    required this.montoApertura,
    this.montoCierre,
    this.montoEsperado,
    this.diferencia,
    required this.totalVentas,
    required this.totalEfectivo,
    required this.totalTarjetaDebito,
    required this.totalTarjetaCredito,
    required this.totalTransferencia,
    required this.totalSinpe,
    required this.totalOtros,
    required this.totalEntradas,
    required this.totalSalidas,
    required this.cantidadTransacciones,
    required this.estado,
    this.fechaApertura,
    this.fechaCierre,
    this.notasApertura,
    this.notasCierre,
  });

  bool get abierta => estado == 'abierta';
  bool get cerrada => estado == 'cerrada';
  bool get auditada => estado == 'auditada';

  factory SesionCajaRead.fromJson(Map<String, dynamic> json) =>
      SesionCajaRead(
        id: json['id'],
        cajaId: json['caja_id'],
        usuarioId: json['usuario_id'],
        numeroSesion: json['numero_sesion'],
        montoApertura:
            double.tryParse(json['monto_apertura'].toString()) ?? 0,
        montoCierre: json['monto_cierre'] != null
            ? double.tryParse(json['monto_cierre'].toString())
            : null,
        montoEsperado: json['monto_esperado'] != null
            ? double.tryParse(json['monto_esperado'].toString())
            : null,
        diferencia: json['diferencia'] != null
            ? double.tryParse(json['diferencia'].toString())
            : null,
        totalVentas:
            double.tryParse(json['total_ventas'].toString()) ?? 0,
        totalEfectivo:
            double.tryParse(json['total_efectivo'].toString()) ?? 0,
        totalTarjetaDebito:
            double.tryParse(json['total_tarjeta_debito'].toString()) ?? 0,
        totalTarjetaCredito:
            double.tryParse(json['total_tarjeta_credito'].toString()) ?? 0,
        totalTransferencia:
            double.tryParse(json['total_transferencia'].toString()) ?? 0,
        totalSinpe:
            double.tryParse(json['total_sinpe'].toString()) ?? 0,
        totalOtros:
            double.tryParse(json['total_otros'].toString()) ?? 0,
        totalEntradas:
            double.tryParse(json['total_entradas'].toString()) ?? 0,
        totalSalidas:
            double.tryParse(json['total_salidas'].toString()) ?? 0,
        cantidadTransacciones: json['cantidad_transacciones'] ?? 0,
        estado: json['estado'] ?? 'abierta',
        fechaApertura: json['fecha_apertura'] != null
            ? DateTime.tryParse(json['fecha_apertura'])
            : null,
        fechaCierre: json['fecha_cierre'] != null
            ? DateTime.tryParse(json['fecha_cierre'])
            : null,
        notasApertura: json['notas_apertura'],
        notasCierre: json['notas_cierre'],
      );
}

class MovimientoCajaRead {
  final String id;
  final String sesionCajaId;
  final String tipo;
  final String concepto;
  final double monto;
  final String? metodoPago;
  final String? comprobante;
  final String? beneficiario;
  final String? notas;
  final DateTime? createdAt;

  const MovimientoCajaRead({
    required this.id,
    required this.sesionCajaId,
    required this.tipo,
    required this.concepto,
    required this.monto,
    this.metodoPago,
    this.comprobante,
    this.beneficiario,
    this.notas,
    this.createdAt,
  });

  bool get esEntrada => tipo == 'entrada';

  factory MovimientoCajaRead.fromJson(Map<String, dynamic> json) =>
      MovimientoCajaRead(
        id: json['id'],
        sesionCajaId: json['sesion_caja_id'],
        tipo: json['tipo'],
        concepto: json['concepto'],
        monto: double.tryParse(json['monto'].toString()) ?? 0,
        metodoPago: json['metodo_pago'],
        comprobante: json['comprobante'],
        beneficiario: json['beneficiario'],
        notas: json['notas'],
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'])
            : null,
      );
}

class PaginatedCajas {
  final List<CajaRead> items;
  final int total;

  const PaginatedCajas({required this.items, required this.total});

  factory PaginatedCajas.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] ?? json['items']) as List<dynamic>;
    return PaginatedCajas(
      items: list
          .map((i) => CajaRead.fromJson(i as Map<String, dynamic>))
          .toList(),
      total: json['total'] ?? 0,
    );
  }
}

class PaginatedSesiones {
  final List<SesionCajaRead> items;
  final int total;
  final int page;
  final int pages;

  const PaginatedSesiones({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  factory PaginatedSesiones.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] ?? json['items']) as List<dynamic>;
    return PaginatedSesiones(
      items: list
          .map((i) => SesionCajaRead.fromJson(i as Map<String, dynamic>))
          .toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      pages: json['total_pages'] ?? json['pages'] ?? 1,
    );
  }
}

class PaginatedMovimientos {
  final List<MovimientoCajaRead> items;
  final int total;

  const PaginatedMovimientos({required this.items, required this.total});

  factory PaginatedMovimientos.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] ?? json['items']) as List<dynamic>;
    return PaginatedMovimientos(
      items: list
          .map((i) =>
              MovimientoCajaRead.fromJson(i as Map<String, dynamic>))
          .toList(),
      total: json['total'] ?? 0,
    );
  }
}