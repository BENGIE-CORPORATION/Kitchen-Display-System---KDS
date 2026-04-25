class ProveedorRead {
  final String id;
  final String empresaId;
  final String identificacion;
  final String nombreLegal;
  final String? codigo;
  final String? tipoIdentificacion;
  final String? nombreComercial;
  final String? tipoProveedor;
  final String? email;
  final String? telefono;
  final String? telefonoAlternativo;
  final String? direccion;
  final String? ciudad;
  final String? pais;
  final String? sitioWeb;
  final String? personaContacto;
  final String? cargoContacto;
  final String? emailContacto;
  final String? telefonoContacto;
  final String condicionPago;
  final double? limiteCredito;
  final String? cuentaBancaria;
  final String? notas;
  final int? calificacion;
  final String estado;

  const ProveedorRead({
    required this.id,
    required this.empresaId,
    required this.identificacion,
    required this.nombreLegal,
    this.codigo,
    this.tipoIdentificacion,
    this.nombreComercial,
    this.tipoProveedor,
    this.email,
    this.telefono,
    this.telefonoAlternativo,
    this.direccion,
    this.ciudad,
    this.pais,
    this.sitioWeb,
    this.personaContacto,
    this.cargoContacto,
    this.emailContacto,
    this.telefonoContacto,
    required this.condicionPago,
    this.limiteCredito,
    this.cuentaBancaria,
    this.notas,
    this.calificacion,
    required this.estado,
  });

  factory ProveedorRead.fromJson(Map<String, dynamic> json) => ProveedorRead(
        id: json['id'],
        empresaId: json['empresa_id'],
        identificacion: json['identificacion'],
        nombreLegal: json['nombre_legal'],
        codigo: json['codigo'],
        tipoIdentificacion: json['tipo_identificacion'],
        nombreComercial: json['nombre_comercial'],
        tipoProveedor: json['tipo_proveedor'],
        email: json['email'],
        telefono: json['telefono'],
        telefonoAlternativo: json['telefono_alternativo'],
        direccion: json['direccion'],
        ciudad: json['ciudad'],
        pais: json['pais'],
        sitioWeb: json['sitio_web'],
        personaContacto: json['persona_contacto'],
        cargoContacto: json['cargo_contacto'],
        emailContacto: json['email_contacto'],
        telefonoContacto: json['telefono_contacto'],
        condicionPago: json['condicion_pago'] ?? 'contado',
        limiteCredito: json['limite_credito'] != null
            ? double.tryParse(json['limite_credito'].toString())
            : null,
        cuentaBancaria: json['cuenta_bancaria'],
        notas: json['notas'],
        calificacion: json['calificacion'],
        estado: json['estado'] ?? 'activo',
      );

  Map<String, dynamic> toTableRow() => {
        'nombreLegal': nombreLegal,
        'identificacion': identificacion,
        'tipoProveedor': tipoProveedor ?? '—',
        'condicionPago': condicionPago,
        'telefono': telefono ?? '—',
        'email': email ?? '—',
        'ciudad': ciudad ?? '—',
        'estado': estado,
        '_ref': this,
      };
}

class PaginatedProveedores {
  final List<ProveedorRead> items;
  final int total;
  final int page;
  final int pages;

  const PaginatedProveedores({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  factory PaginatedProveedores.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] ?? json['items']) as List<dynamic>;
    return PaginatedProveedores(
      items: list
          .map((i) => ProveedorRead.fromJson(i as Map<String, dynamic>))
          .toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      pages: json['total_pages'] ?? json['pages'] ?? 1,
    );
  }
}