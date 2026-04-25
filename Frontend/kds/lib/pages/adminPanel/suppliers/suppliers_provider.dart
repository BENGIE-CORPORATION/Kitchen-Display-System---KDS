import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../common/models/proveedor_models.dart';
import '../../../common/providers/auth_provider.dart';
import '../../../common/services/api_service.dart';

class SuppliersService {
  static Future<PaginatedProveedores> getProveedores({
    required AuthProvider auth,
    int page = 1,
    int itemsPerPage = 50,
    String? search,
    String? tipoProveedor,
    String? condicionPago,
    String? estado,
  }) async {
    // super_admin requiere empresa_id como query param
    final empresaId = auth.isSuperAdmin
        ? auth.sucursalSeleccionada?.empresaId ?? auth.empresaId
        : auth.empresaId;

    if (empresaId == null) throw ApiException(400, 'No se pudo determinar la empresa');

    final params = StringBuffer('/api/v1/proveedores/?empresa_id=$empresaId'
        '&page=$page&items_per_page=$itemsPerPage');

    if (search != null && search.isNotEmpty) params.write('&search=$search');
    if (tipoProveedor != null) params.write('&tipo_proveedor=$tipoProveedor');
    if (condicionPago != null) params.write('&condicion_pago=$condicionPago');
    if (estado != null) params.write('&estado=$estado');

    final data = await ApiService.get(params.toString());
    return PaginatedProveedores.fromJson(data);
  }

  static Future<ProveedorRead> createProveedor(Map<String, dynamic> body) async {
    final data = await ApiService.post('/api/v1/proveedores/', body);
    return ProveedorRead.fromJson(data);
  }

  static Future<ProveedorRead> updateProveedor(
      String id, Map<String, dynamic> body) async {
    final data = await ApiService.patch('/api/v1/proveedores/$id', body);
    return ProveedorRead.fromJson(data);
  }

  static Future<void> deleteProveedor(String id) async {
    await ApiService.delete('/api/v1/proveedores/$id');
  }
}

class SuppliersProvider extends ChangeNotifier {
  List<ProveedorRead> items = [];
  int total = 0;
  bool isLoading = false;
  String? error;

  AuthProvider? _auth;

  void init(AuthProvider auth) {
    _auth = auth;
  }

  Future<void> load({bool refresh = false}) async {
    if (_auth == null) return;
    if (refresh) items = [];

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final result = await SuppliersService.getProveedores(auth: _auth!);
      items = result.items;
      total = result.total;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Error al cargar los proveedores';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => load(refresh: true);

  List<ProveedorRead> filtrar({
    String query = '',
    String tipoProveedor = 'Todos',
    String condicionPago = 'Todas',
  }) {
    return items.where((p) {
      final q = query.toLowerCase();
      final matchSearch = q.isEmpty ||
          p.nombreLegal.toLowerCase().contains(q) ||
          p.identificacion.toLowerCase().contains(q) ||
          (p.nombreComercial?.toLowerCase().contains(q) ?? false) ||
          (p.email?.toLowerCase().contains(q) ?? false);
      final matchTipo =
          tipoProveedor == 'Todos' || p.tipoProveedor == tipoProveedor;
      final matchPago =
          condicionPago == 'Todas' || p.condicionPago == condicionPago;
      return matchSearch && matchTipo && matchPago;
    }).toList();
  }

  List<String> get tiposProveedor {
    final tipos = items
        .map((p) => p.tipoProveedor ?? 'Sin tipo')
        .toSet()
        .toList()
      ..sort();
    return ['Todos', ...tipos];
  }

  List<String> get condicionesPago {
    final condiciones = items.map((p) => p.condicionPago).toSet().toList()
      ..sort();
    return ['Todas', ...condiciones];
  }
}