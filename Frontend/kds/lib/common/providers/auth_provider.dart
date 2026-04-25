import 'package:flutter/material.dart';
import '../models/auth_models.dart';
import '../models/user_models.dart';
import '../models/sucursal_models.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

enum AuthStatus { checking, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus status = AuthStatus.checking;
  String? errorMessage;
  bool isLoading = false;

  // Datos del usuario autenticado
  MeResponse? me;

  // Para super_admin: lista de todas las sucursales y la seleccionada
  List<SucursalRead> todasLasSucursales = [];
  SucursalRead? sucursalSeleccionada;

  // ── Getters ────────────────────────────────────────────────────────────────
  PerfilRead? get perfil        => me?.perfil;
  String?     get empresaId     => me?.perfil.empresaId;
  String?     get nombreUsuario => me?.perfil.nombreCompleto;
  String?     get rolGlobal     => me?.perfil.rolGlobal;
  bool        get isSuperAdmin  => rolGlobal == 'super_admin';

  /// super_admin usa la sucursal seleccionada manualmente.
  /// Otros roles usan su sucursal principal asignada.
  String? get sucursalId {
    if (isSuperAdmin) return sucursalSeleccionada?.id;
    return me?.sucursalIdPrincipal;
  }

  String? get sucursalNombre {
    if (isSuperAdmin) return sucursalSeleccionada?.nombre;
    return me?.sucursalPrincipal?.nombreSucursal;
  }

  // ── Verifica sesión al iniciar la app ──────────────────────────────────────
  Future<void> checkSession() async {
    status = AuthStatus.checking;
    notifyListeners();

    final hasSession = await AuthService.hasActiveSession();
    if (!hasSession) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    await _loadMe();
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await AuthService.login(LoginRequest(email: email, password: password));
      await _loadMe();
      return true;
    } on AuthException catch (e) {
      errorMessage = e.message;
      status = AuthStatus.unauthenticated;
      return false;
    } catch (_) {
      errorMessage = 'Error de conexión. Verifica tu red.';
      status = AuthStatus.unauthenticated;
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    isLoading = true;
    notifyListeners();

    await AuthService.logout();

    me = null;
    todasLasSucursales = [];
    sucursalSeleccionada = null;
    status = AuthStatus.unauthenticated;
    isLoading = false;
    notifyListeners();
  }

  // ── Seleccionar sucursal (solo super_admin) ────────────────────────────────
  void seleccionarSucursal(SucursalRead sucursal) {
    sucursalSeleccionada = sucursal;
    notifyListeners();
  }

  // ── Carga perfil desde /auth/me ────────────────────────────────────────────
  Future<void> _loadMe() async {
    try {
      final data = await ApiService.get('/api/v1/auth/me');
      me = MeResponse.fromJson(data);

      if (isSuperAdmin) {
        await _loadTodasLasSucursales();
      }

      status = AuthStatus.authenticated;
    } catch (_) {
      await AuthService.logout();
      me = null;
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ── Carga todas las sucursales para super_admin ────────────────────────────
  Future<void> _loadTodasLasSucursales() async {
    try {
      final data = await ApiService.get(
          '/api/v1/sucursales/?items_per_page=100&estado=activo');
      
      final paginated = PaginatedSucursales.fromJson(data);
      todasLasSucursales = paginated.items;

      // Selecciona la primera por defecto
      //if (todasLasSucursales.isNotEmpty && sucursalSeleccionada == null) {
      // sucursalSeleccionada = todasLasSucursales.first;
      //}
    } catch (e) {
      print('Error sucursales: $e');
      todasLasSucursales = [];
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
}