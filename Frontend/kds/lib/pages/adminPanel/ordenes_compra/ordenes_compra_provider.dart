import 'package:flutter/material.dart';
import '../../../common/models/orden_compra_models.dart';
import '../../../common/models/proveedor_models.dart';
import '../../../common/providers/auth_provider.dart';
import '../../../common/services/api_service.dart';

class OrdenesCompraService {
  static Future<PaginatedOrdenesCompra> getOrdenes({
    required AuthProvider auth,
    int page = 1,
    int itemsPerPage = 50,
    String? estado,
    String? proveedorId,
  }) async {
    final empresaId = auth.isSuperAdmin
        ? auth.sucursalSeleccionada?.empresaId ?? auth.empresaId
        : auth.empresaId;

    if (empresaId == null) throw ApiException(400, 'No se pudo determinar la empresa');

    final params = StringBuffer(
        '/api/v1/ordenes-compra/?empresa_id=$empresaId&page=$page&items_per_page=$itemsPerPage');
    if (estado != null) params.write('&estado=$estado');
    if (proveedorId != null) params.write('&proveedor_id=$proveedorId');

    final data = await ApiService.get(params.toString());
    return PaginatedOrdenesCompra.fromJson(data);
  }

  static Future<OrdenCompraReadDetalle> getOrdenDetalle(String id) async {
    final data = await ApiService.get('/api/v1/ordenes-compra/$id/detalle');
    return OrdenCompraReadDetalle.fromJson(data);
  }

  static Future<OrdenCompraRead> createOrden(Map<String, dynamic> body) async {
    final data = await ApiService.post('/api/v1/ordenes-compra/', body);
    return OrdenCompraRead.fromJson(data);
  }

  static Future<OrdenCompraRead> cambiarEstado(
    String id,
    String nuevoEstado, {
    String? fechaEntregaReal,
    String? notas,
  }) async {
    final body = <String, dynamic>{'estado': nuevoEstado};
    if (fechaEntregaReal != null) body['fecha_entrega_real'] = fechaEntregaReal;
    if (notas != null) body['notas'] = notas;
    final data = await ApiService.patch('/api/v1/ordenes-compra/$id/estado', body);
    return OrdenCompraRead.fromJson(data);
  }

  static Future<void> cancelarOrden(String id) async {
    await ApiService.delete('/api/v1/ordenes-compra/$id');
  }

  static Future<void> registrarRecepcionItem({
    required String ordenId,
    required String itemId,
    required double cantidadRecibida,
  }) async {
    await ApiService.patch(
      '/api/v1/ordenes-compra/$ordenId/items/$itemId/recepcion',
      {'cantidad_recibida': cantidadRecibida},
    );
  }
}

class OrdenesCompraProvider extends ChangeNotifier {
  List<OrdenCompraRead> items = [];
  int total = 0;
  bool isLoading = false;
  String? error;
  String _estadoFilter = 'Todos';

  String get estadoFilter => _estadoFilter;

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
      final result = await OrdenesCompraService.getOrdenes(
        auth: _auth!,
        estado: _estadoFilter == 'Todos' ? null : _estadoFilter,
      );
      items = result.items;
      total = result.total;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Error al cargar las órdenes de compra';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => load(refresh: true);

  void setEstadoFilter(String estado) {
    _estadoFilter = estado;
    load(refresh: true);
  }

  List<OrdenCompraRead> filtrar({String query = ''}) {
    if (query.isEmpty) return items;
    final q = query.toLowerCase();
    return items.where((o) =>
        o.numeroOrden.toLowerCase().contains(q) ||
        o.estado.toLowerCase().contains(q)).toList();
  }
}