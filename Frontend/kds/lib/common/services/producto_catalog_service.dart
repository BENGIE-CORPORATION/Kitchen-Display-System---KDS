import '../models/producto_models.dart';
import 'api_service.dart';

/// Catálogo de productos de una sucursal, con resolución de nombre por id —
/// usado por App de Empleados (carrito) y Kitchen Display (tickets), ya que
/// DetallePedidoRead solo trae producto_id, no el nombre.
class ProductoCatalogService {
  static Future<List<ProductoSucursalRead>> getCatalogo(
    String sucursalId, {
    bool soloDisponibles = true,
  }) async {
    final data = await ApiService.get(
        '/api/v1/productos/sucursal/$sucursalId?items_per_page=200'
        '${soloDisponibles ? '&disponible_venta=true' : ''}');
    return PaginatedProductosSucursal.fromJson(data).items;
  }

  static Future<List<CategoriaRead>> getCategorias(String empresaId) async {
    final data = await ApiService.get(
        '/api/v1/categorias/?empresa_id=$empresaId&items_per_page=100&estado=activo');
    final list = (data['data'] ?? data['items']) as List<dynamic>;
    return list.map((i) => CategoriaRead.fromJson(i as Map<String, dynamic>)).toList();
  }

  static Future<List<VarianteRead>> getVariantes(String productoId) async {
    final data = await ApiService.get('/api/v1/productos/$productoId/variantes');
    final list = data as List<dynamic>;
    return list.map((i) => VarianteRead.fromJson(i as Map<String, dynamic>)).toList();
  }
}

/// Índice productoId -> nombre, construido a partir de un catálogo ya cargado.
class ProductoNombreResolver {
  final Map<String, String> _nombres;

  ProductoNombreResolver(List<ProductoSucursalRead> catalogo)
      : _nombres = {
          for (final p in catalogo) p.productoId: p.nombre ?? 'Producto',
        };

  String nombreDe(String productoId) => _nombres[productoId] ?? 'Producto';
}
