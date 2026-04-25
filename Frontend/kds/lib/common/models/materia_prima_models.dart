// ─── Materia Prima Models ─────────────────────────────────────────────────────

class MateriaPrimaRead {
  final String id;
  final String empresaId;
  final String nombre;
  final String unidadMedida;
  final String? codigo;
  final String? descripcion;
  final String? categoria;
  final bool perecedero;
  final int? diasVidaUtil;
  final String estado;

  const MateriaPrimaRead({
    required this.id,
    required this.empresaId,
    required this.nombre,
    required this.unidadMedida,
    this.codigo,
    this.descripcion,
    this.categoria,
    required this.perecedero,
    this.diasVidaUtil,
    required this.estado,
  });

  factory MateriaPrimaRead.fromJson(Map<String, dynamic> json) =>
      MateriaPrimaRead(
        id: json['id'],
        empresaId: json['empresa_id'],
        nombre: json['nombre'],
        unidadMedida: json['unidad_medida'],
        codigo: json['codigo'],
        descripcion: json['descripcion'],
        categoria: json['categoria'],
        perecedero: json['perecedero'] ?? false,
        diasVidaUtil: json['dias_vida_util'],
        estado: json['estado'] ?? 'activo',
      );
}

class MateriaPrimaSucursalRead {
  final String id;
  final String materiaPrimaId;
  final String sucursalId;
  final double stockActual;
  final double stockMinimo;
  final double? stockMaximo;
  final double costoPromedio;
  final double? ultimoCosto;
  final String? ubicacionFisica;

  // Campos del join con materias_primas
  final String? nombre;
  final String? unidadMedida;
  final String? categoria;
  final String? codigo;
  final String? descripcion;
  final bool perecedero;
  final String? estado;

  const MateriaPrimaSucursalRead({
    required this.id,
    required this.materiaPrimaId,
    required this.sucursalId,
    required this.stockActual,
    required this.stockMinimo,
    this.stockMaximo,
    required this.costoPromedio,
    this.ultimoCosto,
    this.ubicacionFisica,
    this.nombre,
    this.unidadMedida,
    this.categoria,
    this.codigo,
    this.descripcion,
    this.perecedero = false,
    this.estado,
  });

  bool get isBajoMinimo => stockActual <= stockMinimo;

  factory MateriaPrimaSucursalRead.fromJson(Map<String, dynamic> json) {
    // El endpoint GET /materias-primas/sucursal/{id} hace:
    //   select("*, materias_primas(*)")
    // Los campos de la materia prima llegan anidados bajo la clave
    // "materias_primas", no en el nivel raíz del JSON.
    final mp = json['materias_primas'] as Map<String, dynamic>? ?? {};

    return MateriaPrimaSucursalRead(
      // Campos propios de la relación sucursal
      id: json['id'],
      materiaPrimaId: json['materia_prima_id'],
      sucursalId: json['sucursal_id'],
      stockActual: double.tryParse(json['stock_actual'].toString()) ?? 0,
      stockMinimo: double.tryParse(json['stock_minimo'].toString()) ?? 0,
      stockMaximo: json['stock_maximo'] != null
          ? double.tryParse(json['stock_maximo'].toString())
          : null,
      costoPromedio: double.tryParse(json['costo_promedio'].toString()) ?? 0,
      ultimoCosto: json['ultimo_costo'] != null
          ? double.tryParse(json['ultimo_costo'].toString())
          : null,
      ubicacionFisica: json['ubicacion_fisica'],

      // Campos del join — se leen del objeto anidado "materias_primas"
      nombre: mp['nombre'] as String?,
      unidadMedida: mp['unidad_medida'] as String?,
      categoria: mp['categoria'] as String?,
      codigo: mp['codigo'] as String?,
      descripcion: mp['descripcion'] as String?,
      perecedero: mp['perecedero'] as bool? ?? false,
      estado: mp['estado'] as String?,
    );
  }

  Map<String, dynamic> toTableRow() => {
        'nombre': nombre ?? '—',
        'codigo': codigo ?? '—',
        'categoria': categoria ?? '—',
        'unidadMedida': unidadMedida ?? '—',
        'stockActual': stockActual,
        'stockMinimo': stockMinimo,
        'costoPromedio': costoPromedio,
        'estado': isBajoMinimo ? 'low' : 'available',
        '_ref': this,
      };
}

class PaginatedMateriaPrimas {
  final List<MateriaPrimaSucursalRead> items;
  final int total;
  final int page;
  final int pages;

  const PaginatedMateriaPrimas({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  factory PaginatedMateriaPrimas.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] ?? json['items']) as List<dynamic>;
    return PaginatedMateriaPrimas(
      items: list
          .map((i) =>
              MateriaPrimaSucursalRead.fromJson(i as Map<String, dynamic>))
          .toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      pages: json['total_pages'] ?? json['pages'] ?? 1,
    );
  }
}