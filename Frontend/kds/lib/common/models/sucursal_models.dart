// ─── Sucursal Models ──────────────────────────────────────────────────────────

class SucursalRead {
  final String id;
  final String empresaId;
  final String codigo;
  final String nombre;
  final String tipo;
  final String? ciudad;
  final String? direccion;
  final String? telefono;
  final String estado;

  const SucursalRead({
    required this.id,
    required this.empresaId,
    required this.codigo,
    required this.nombre,
    required this.tipo,
    this.ciudad,
    this.direccion,
    this.telefono,
    required this.estado,
  });

  factory SucursalRead.fromJson(Map<String, dynamic> json) => SucursalRead(
        id: json['id'],
        empresaId: json['empresa_id'],
        codigo: json['codigo'],
        nombre: json['nombre'],
        tipo: json['tipo'],
        ciudad: json['ciudad'],
        direccion: json['direccion'],
        telefono: json['telefono'],
        estado: json['estado'] ?? 'activo',
      );
}

class PaginatedSucursales {
  final List<SucursalRead> items;
  final int total;

  const PaginatedSucursales({required this.items, required this.total});

  factory PaginatedSucursales.fromJson(Map<String, dynamic> json) =>
      PaginatedSucursales(
        items: (json['items'] as List<dynamic>)
            .map((i) => SucursalRead.fromJson(i))
            .toList(),
        total: json['total'] ?? 0,
      );
}