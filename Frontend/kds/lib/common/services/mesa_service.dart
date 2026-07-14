import '../models/mesa_models.dart';
import '../models/pedido_models.dart';
import 'api_service.dart';

class MesaService {
  static Future<PaginatedMesas> getMesas(
    String sucursalId, {
    String? estado,
    String? zona,
    int itemsPerPage = 100,
  }) async {
    final params = StringBuffer(
        '/api/v1/mesas/?sucursal_id=$sucursalId&items_per_page=$itemsPerPage');
    if (estado != null) params.write('&estado=$estado');
    if (zona != null) params.write('&zona=$zona');
    final data = await ApiService.get(params.toString());
    return PaginatedMesas.fromJson(data);
  }

  static Future<PedidoRead?> getPedidoActivo(String mesaId) async {
    try {
      final data = await ApiService.get('/api/v1/mesas/$mesaId/pedido-activo');
      return PedidoRead.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  static Future<MesaRead> cambiarEstado(String mesaId, String estado) async {
    final data =
        await ApiService.patch('/api/v1/mesas/$mesaId/estado', {'estado': estado});
    return MesaRead.fromJson(data);
  }
}
