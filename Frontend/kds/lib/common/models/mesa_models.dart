// ─── Mesa Models ──────────────────────────────────────────────────────────────
// Alineado con /mesas del backend (ver Backend/Doc/API_REFERENCE.md, sección 14).

class MesaRead {
  final String id;
  final String sucursalId;
  final int numero;
  final int capacidad;
  final String? zona;
  final String estado; // libre | ocupada | reservada | fuera_de_servicio
  final String? notas;

  const MesaRead({
    required this.id,
    required this.sucursalId,
    required this.numero,
    required this.capacidad,
    this.zona,
    required this.estado,
    this.notas,
  });

  bool get libre => estado == 'libre';
  bool get ocupada => estado == 'ocupada';
  bool get reservada => estado == 'reservada';
  bool get fueraDeServicio => estado == 'fuera_de_servicio';

  factory MesaRead.fromJson(Map<String, dynamic> json) => MesaRead(
        id: json['id'],
        sucursalId: json['sucursal_id'],
        numero: json['numero'] is int
            ? json['numero']
            : int.tryParse(json['numero'].toString()) ?? 0,
        capacidad: json['capacidad'] is int
            ? json['capacidad']
            : int.tryParse(json['capacidad'].toString()) ?? 0,
        zona: json['zona'],
        estado: json['estado'] ?? 'libre',
        notas: json['notas'],
      );
}

class PaginatedMesas {
  final List<MesaRead> items;
  final int total;

  const PaginatedMesas({required this.items, required this.total});

  factory PaginatedMesas.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] ?? json['items']) as List<dynamic>;
    return PaginatedMesas(
      items: list.map((i) => MesaRead.fromJson(i as Map<String, dynamic>)).toList(),
      total: json['total'] ?? 0,
    );
  }
}
