// ─── User Models (desde /auth/me) ────────────────────────────────────────────

class PerfilRead {
  final String id;
  final String empresaId;
  final String nombreCompleto;
  final String email;
  final String? telefono;
  final String? avatarUrl;
  final String rolGlobal;
  final String estado;

  const PerfilRead({
    required this.id,
    required this.empresaId,
    required this.nombreCompleto,
    required this.email,
    this.telefono,
    this.avatarUrl,
    required this.rolGlobal,
    required this.estado,
  });

  factory PerfilRead.fromJson(Map<String, dynamic> json) => PerfilRead(
        id: json['id'],
        empresaId: json['empresa_id'],
        nombreCompleto: json['nombre_completo'],
        email: json['email'],
        telefono: json['telefono'],
        avatarUrl: json['avatar_url'],
        rolGlobal: json['rol_global'],
        estado: json['estado'],
      );
}

class SucursalAsignada {
  final String sucursalId;
  final String rolSucursal;
  final bool esPrincipal;
  final String estado;
  final String? nombreSucursal; // puede venir en el join

  const SucursalAsignada({
    required this.sucursalId,
    required this.rolSucursal,
    required this.esPrincipal,
    required this.estado,
    this.nombreSucursal,
  });

  factory SucursalAsignada.fromJson(Map<String, dynamic> json) => SucursalAsignada(
        sucursalId: json['sucursal_id'],
        rolSucursal: json['rol_sucursal'],
        esPrincipal: json['es_principal'] ?? false,
        estado: json['estado'] ?? 'activo',
        nombreSucursal: json['nombre'],
      );
}

class MeResponse {
  final PerfilRead perfil;
  final List<SucursalAsignada> sucursales;

  const MeResponse({required this.perfil, required this.sucursales});

  /// Retorna la sucursal principal del usuario.
  /// Si no tiene principal marcada, retorna la primera activa.
  SucursalAsignada? get sucursalPrincipal {
    try {
      return sucursales.firstWhere(
        (s) => s.esPrincipal && s.estado == 'activo',
      );
    } catch (_) {
      try {
        return sucursales.firstWhere((s) => s.estado == 'activo');
      } catch (_) {
        return sucursales.isNotEmpty ? sucursales.first : null;
      }
    }
  }

  String? get sucursalIdPrincipal => sucursalPrincipal?.sucursalId;

  factory MeResponse.fromJson(Map<String, dynamic> json) => MeResponse(
        perfil: PerfilRead.fromJson(json['perfil']),
        sucursales: (json['sucursales'] as List<dynamic>? ?? [])
            .map((s) => SucursalAsignada.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}