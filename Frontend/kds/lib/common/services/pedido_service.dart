import '../models/pedido_models.dart';
import '../models/pago_models.dart';
import 'api_service.dart';

/// Servicio compartido de /pedidos para App de Empleados y Kitchen Display.
/// Espeja los métodos ya probados en adminPanel/sales/sales_provider.dart
/// (SalesService) — se mantiene separado para no tocar el módulo de admin.
class PedidoService {
  static Future<PaginatedPedidos> getPedidos({
    required String empresaId,
    String? sucursalId,
    int page = 1,
    int itemsPerPage = 100,
    String? estado,
    String? tipoPedido,
  }) async {
    final params = StringBuffer(
        '/api/v1/pedidos/?empresa_id=$empresaId&page=$page&items_per_page=$itemsPerPage');
    if (sucursalId != null) params.write('&sucursal_id=$sucursalId');
    if (estado != null) params.write('&estado=$estado');
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

  static Future<void> addItem(String pedidoId, Map<String, dynamic> body) async {
    await ApiService.post('/api/v1/pedidos/$pedidoId/items', body);
  }

  static Future<void> updateItem(
      String pedidoId, String itemId, Map<String, dynamic> body) async {
    await ApiService.patch('/api/v1/pedidos/$pedidoId/items/$itemId', body);
  }

  static Future<void> cancelItem(
      String pedidoId, String itemId, String motivo) async {
    await ApiService.delete(
        '/api/v1/pedidos/$pedidoId/items/$itemId?motivo_cancelacion=$motivo');
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

  static Future<void> registrarPago(
      String pedidoId, Map<String, dynamic> body) async {
    await ApiService.post('/api/v1/pedidos/$pedidoId/pagos', body);
  }
}
