import 'package:flutter/material.dart';
import '../../../common/providers/auth_provider.dart';
import '../../../common/services/api_service.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class PerfilPublicRead {
  final String id;
  final String nombreCompleto;
  final String email;
  final String? avatarUrl;
  final String rolGlobal;
  final String estado;

  const PerfilPublicRead({
    required this.id,
    required this.nombreCompleto,
    required this.email,
    this.avatarUrl,
    required this.rolGlobal,
    required this.estado,
  });

  factory PerfilPublicRead.fromJson(Map<String, dynamic> j) =>
      PerfilPublicRead(
        id: j['id'] as String,
        nombreCompleto: j['nombre_completo'] as String,
        email: j['email'] as String,
        avatarUrl: j['avatar_url'] as String?,
        rolGlobal: j['rol_global'] as String,
        estado: j['estado'] as String,
      );
}

class PerfilRead extends PerfilPublicRead {
  final String empresaId;
  final String? telefono;
  final String? ultimoAcceso;
  final String? createdAt;
  final List<Map<String, dynamic>> sucursales;

  const PerfilRead({
    required super.id,
    required super.nombreCompleto,
    required super.email,
    super.avatarUrl,
    required super.rolGlobal,
    required super.estado,
    required this.empresaId,
    this.telefono,
    this.ultimoAcceso,
    this.createdAt,
    this.sucursales = const [],
  });

  factory PerfilRead.fromJson(Map<String, dynamic> j) => PerfilRead(
        id: j['id'] as String,
        nombreCompleto: j['nombre_completo'] as String,
        email: j['email'] as String,
        avatarUrl: j['avatar_url'] as String?,
        rolGlobal: j['rol_global'] as String,
        estado: j['estado'] as String,
        empresaId: j['empresa_id'] as String,
        telefono: j['telefono'] as String?,
        ultimoAcceso: j['ultimo_acceso'] as String?,
        createdAt: j['created_at'] as String?,
        sucursales: const [],
      );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class EmployeesService {
  static Future<Map<String, dynamic>> getPerfiles({
    required String empresaId,
    int page = 1,
    int itemsPerPage = 20,
    String? estado,
    String? rolGlobal,
  }) async {
    final params = StringBuffer(
        '/api/v1/perfiles/empresa/$empresaId?page=$page&items_per_page=$itemsPerPage');
    if (estado != null) params.write('&estado=$estado');
    if (rolGlobal != null) params.write('&rol_global=$rolGlobal');

    return await ApiService.get(params.toString());
  }

  static Future<Map<String, dynamic>> getPerfilById(String userId) async =>
      await ApiService.get('/api/v1/perfiles/$userId');

  static Future<void> crearEmpleado({
    required String empresaId,
    required String email,
    required String password,
    required String nombreCompleto,
    required String rolGlobal,
    String? telefono,
  }) async {
    // El BE crea el usuario en Supabase Auth + perfil en una sola operacion
    await ApiService.post('/api/v1/auth/register',  {
      'email': email,
      'password': password,
      'nombre_completo': nombreCompleto,
      'rol_global': rolGlobal,
      'empresa_id': empresaId,
      if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
    });
  }

  static Future<Map<String, dynamic>> actualizarPerfil({
    required String userId,
    String? nombreCompleto,
    String? telefono,
  }) async {
    final body = <String, dynamic>{};
    if (nombreCompleto != null) body['nombre_completo'] = nombreCompleto;
    if (telefono != null) body['telefono'] = telefono;

    return await ApiService.patch('/api/v1/perfiles/$userId', body);
  }

  static Future<Map<String, dynamic>> cambiarRol({
    required String userId,
    required String rolGlobal,
  }) async =>
      await ApiService.patch('/api/v1/perfiles/$userId/rol',
          {'rol_global': rolGlobal});

  static Future<Map<String, dynamic>> cambiarEstado({
    required String userId,
    required String estado,
  }) async =>
      await ApiService.patch('/api/v1/perfiles/$userId/estado',
          {'estado': estado});

  static Future<void> softDelete(String userId) async =>
      await ApiService.delete('/api/v1/perfiles/$userId');
}

// ─── Provider ─────────────────────────────────────────────────────────────────

class EmployeesProvider extends ChangeNotifier {
  List<PerfilPublicRead> _perfiles = [];
  bool _isLoading = false;
  String? _error;

  // Filtros
  String? _filtroEstado;
  String? _filtroRol;
  int _page = 1;
  int _total = 0;
  static const int _itemsPerPage = 20;

  // Getters
  List<PerfilPublicRead> get perfiles => _perfiles;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get filtroEstado => _filtroEstado;
  String? get filtroRol => _filtroRol;
  int get page => _page;
  int get total => _total;
  int get totalPages => (_total / _itemsPerPage).ceil();
  bool get hasNextPage => _page < totalPages;
  bool get hasPrevPage => _page > 1;

  late String _empresaId;

  void init(AuthProvider auth) {
    _empresaId = auth.empresaId ?? '';
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await EmployeesService.getPerfiles(
        empresaId: _empresaId,
        page: _page,
        itemsPerPage: _itemsPerPage,
        estado: _filtroEstado,
        rolGlobal: _filtroRol,
      );

      final items = (data['data'] as List? ?? []);
      _perfiles = items.map((e) => PerfilPublicRead.fromJson(e as Map<String, dynamic>)).toList();
      _total = data['total'] as int? ?? 0;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() async {
    _page = 1;
    await load();
  }

  void setFiltroEstado(String? val) {
    _filtroEstado = val;
    reload();
  }

  void setFiltroRol(String? val) {
    _filtroRol = val;
    reload();
  }

  void nextPage() {
    if (hasNextPage) {
      _page++;
      load();
    }
  }

  void prevPage() {
    if (hasPrevPage) {
      _page--;
      load();
    }
  }

  Future<bool> crearEmpleado({
    required String email,
    required String password,
    required String nombreCompleto,
    required String rolGlobal,
    String? telefono,
  }) async {
    try {
      await EmployeesService.crearEmpleado(
        empresaId: _empresaId,
        email: email,
        password: password,
        nombreCompleto: nombreCompleto,
        rolGlobal: rolGlobal,
        telefono: telefono,
      );
      await reload();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> actualizarPerfil({
    required String userId,
    String? nombreCompleto,
    String? telefono,
  }) async {
    try {
      await EmployeesService.actualizarPerfil(
        userId: userId,
        nombreCompleto: nombreCompleto,
        telefono: telefono,
      );
      await reload();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> cambiarRol(String userId, String rolGlobal) async {
    try {
      await EmployeesService.cambiarRol(userId: userId, rolGlobal: rolGlobal);
      await reload();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> cambiarEstado(String userId, String estado) async {
    try {
      await EmployeesService.cambiarEstado(userId: userId, estado: estado);
      await reload();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarEmpleado(String userId) async {
    try {
      await EmployeesService.softDelete(userId);
      await reload();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}