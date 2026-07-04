import 'package:flutter/material.dart';
import '../../../common/models/caja_models.dart';
import '../../../common/providers/auth_provider.dart';
import '../../../common/services/api_service.dart';

class CajaService {
  // ── Cajas ────────────────────────────────────────────────────────────────

  static Future<PaginatedCajas> getCajas(String sucursalId, {
    String? tipo,
    String? estado,
  }) async {
    final params = StringBuffer(
        '/api/v1/cajas/?sucursal_id=$sucursalId&items_per_page=50');
    if (tipo != null) params.write('&tipo=$tipo');
    if (estado != null) params.write('&estado=$estado');
    final data = await ApiService.get(params.toString());
    return PaginatedCajas.fromJson(data);
  }

  static Future<CajaRead> createCaja(Map<String, dynamic> body) async {
    final data = await ApiService.post('/api/v1/cajas/', body);
    return CajaRead.fromJson(data);
  }

  static Future<CajaRead> updateCaja(
      String id, Map<String, dynamic> body) async {
    final data = await ApiService.patch('/api/v1/cajas/$id', body);
    return CajaRead.fromJson(data);
  }

  static Future<void> deleteCaja(String id) async {
    await ApiService.delete('/api/v1/cajas/$id');
  }

  // ── Sesiones ─────────────────────────────────────────────────────────────

  static Future<PaginatedSesiones> getSesiones(String cajaId, {
    String? estado,
    int page = 1,
    int itemsPerPage = 20,
  }) async {
    final params = StringBuffer(
        '/api/v1/cajas/$cajaId/sesiones?page=$page&items_per_page=$itemsPerPage');
    if (estado != null) params.write('&estado=$estado');
    final data = await ApiService.get(params.toString());
    return PaginatedSesiones.fromJson(data);
  }

  static Future<SesionCajaRead?> getSesionActiva(String cajaId) async {
    try {
      final data =
          await ApiService.get('/api/v1/cajas/$cajaId/sesiones/activa');
      return SesionCajaRead.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  static Future<SesionCajaRead> abrirSesion(
      String cajaId, Map<String, dynamic> body) async {
    final data =
        await ApiService.post('/api/v1/cajas/$cajaId/sesiones/abrir', body);
    return SesionCajaRead.fromJson(data);
  }

  static Future<SesionCajaRead> cerrarSesion(
      String sesionId, Map<String, dynamic> body) async {
    final data = await ApiService.patch(
        '/api/v1/cajas/sesiones/$sesionId/cerrar', body);
    return SesionCajaRead.fromJson(data);
  }

  static Future<SesionCajaRead> auditarSesion(String sesionId) async {
    final data = await ApiService.patch(
        '/api/v1/cajas/sesiones/$sesionId/auditar', {});
    return SesionCajaRead.fromJson(data);
  }

  // ── Movimientos ───────────────────────────────────────────────────────────

  static Future<PaginatedMovimientos> getMovimientos(String sesionId, {
    int page = 1,
    int itemsPerPage = 50,
  }) async {
    final data = await ApiService.get(
        '/api/v1/cajas/sesiones/$sesionId/movimientos?page=$page&items_per_page=$itemsPerPage');
    return PaginatedMovimientos.fromJson(data);
  }

  static Future<MovimientoCajaRead> createMovimiento(
      String sesionId, Map<String, dynamic> body) async {
    final data = await ApiService.post(
        '/api/v1/cajas/sesiones/$sesionId/movimientos', body);
    return MovimientoCajaRead.fromJson(data);
  }
}

class CajaProvider extends ChangeNotifier {
  List<CajaRead> cajas = [];
  bool isLoading = false;
  String? error;

  AuthProvider? _auth;

  void init(AuthProvider auth) => _auth = auth;

  String? get _sucursalId => _auth?.isSuperAdmin == true
      ? _auth?.sucursalSeleccionada?.id
      : _auth?.sucursalId;

  Future<void> load({bool refresh = false}) async {
    if (_sucursalId == null) return;
    if (refresh) cajas = [];

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final result = await CajaService.getCajas(_sucursalId!);
      cajas = result.items;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Error al cargar las cajas';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => load(refresh: true);

  String? get sucursalId => _sucursalId;
}