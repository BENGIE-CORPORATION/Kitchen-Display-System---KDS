import 'package:flutter/material.dart';
import '../../../common/models/pedido_models.dart';
import '../../../common/models/pago_models.dart';
import '../../../common/providers/auth_provider.dart';
import '../../../common/services/api_service.dart';

class SalesService {
  static Future<PaginatedPedidos> getPedidos({
    required AuthProvider auth,
    int page = 1,
    int itemsPerPage = 50,
    String? estado,
    String? estadoPago,
    String? tipoPedido,
  }) async {
    final empresaId = auth.isSuperAdmin
        ? auth.sucursalSeleccionada?.empresaId ?? auth.empresaId
        : auth.empresaId;
    final sucursalId = auth.isSuperAdmin
        ? auth.sucursalSeleccionada?.id
        : auth.sucursalId;

    if (empresaId == null)
      throw ApiException(400, 'No se pudo determinar la empresa');

    final params = StringBuffer(
        '/api/v1/pedidos/?empresa_id=$empresaId&page=$page&items_per_page=$itemsPerPage');
    if (sucursalId != null) params.write('&sucursal_id=$sucursalId');
    if (estado != null) params.write('&estado=$estado');
    if (estadoPago != null) params.write('&estado_pago=$estadoPago');
    if (tipoPedido != null) params.write('&tipo_pedido=$tipoPedido');

    final data = await ApiService.get(params.toString());
    return PaginatedPedidos.fromJson(data);
  }

  static Future<PedidoReadDetalle> getPedidoDetalle(String id) async {
    final data = await ApiService.get('/api/v1/pedidos/$id/detalle');
    return PedidoReadDetalle.fromJson(data);
  }

  static Future<PedidoRead> createPedido(Map<String, dynamic> body) async {
    final data = await ApiService.post('/api/v1/pedidos/', body);
    return PedidoRead.fromJson(data);
  }

  static Future<void> registrarPago(
      String pedidoId, Map<String, dynamic> body) async {
    await ApiService.post('/api/v1/pedidos/$pedidoId/pagos', body);
  }

  static Future<PedidoRead> cambiarEstado(
    String id,
    String nuevoEstado, {
    String? motivoCancelacion,
    String? sesionCajaId,
    String? estadoPago,
  }) async {
    final body = <String, dynamic>{'estado': nuevoEstado};
    if (motivoCancelacion != null) body['motivo_cancelacion'] = motivoCancelacion;
    if (sesionCajaId != null) body['sesion_caja_id'] = sesionCajaId;
    if (estadoPago != null) body['estado_pago'] = estadoPago;
    final data = await ApiService.patch('/api/v1/pedidos/$id/estado', body);
    return PedidoRead.fromJson(data);
  }

  static Future<List<PagoRead>> getPagosPedido(String pedidoId) async {
    final data = await ApiService.get('/api/v1/pedidos/$pedidoId/pagos');
    return (data as List<dynamic>)
        .map((i) => PagoRead.fromJson(i as Map<String, dynamic>))
        .toList();
  }
}

class SalesProvider extends ChangeNotifier {
  List<PedidoRead> pedidos = [];
  int total = 0;
  bool isLoading = false;
  String? error;
  String _estadoFilter = 'Todos';

  AuthProvider? _auth;

  void init(AuthProvider auth) => _auth = auth;

  String get estadoFilter => _estadoFilter;

  Future<void> load({bool refresh = false}) async {
    if (_auth == null) return;
    if (refresh) pedidos = [];

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final result = await SalesService.getPedidos(
        auth: _auth!,
        estado: _estadoFilter == 'Todos' ? null : _estadoFilter,
      );
      pedidos = result.items;
      total = result.total;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Error al cargar los pedidos';
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

  List<PedidoRead> filtrar({String query = ''}) {
    if (query.isEmpty) return pedidos;
    final q = query.toLowerCase();
    return pedidos.where((p) =>
        p.numeroPedido.toLowerCase().contains(q) ||
        (p.nombreCliente?.toLowerCase().contains(q) ?? false)).toList();
  }

  int get totalActivos => pedidos.where((p) => !p.esFinal).length;

  double get totalVentasHoy => pedidos
      .where((p) => p.estado == 'facturado')
      .fold(0, (s, p) => s + p.total);
}