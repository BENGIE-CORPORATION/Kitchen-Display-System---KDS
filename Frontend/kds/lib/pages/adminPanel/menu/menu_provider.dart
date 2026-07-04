import 'package:flutter/material.dart';
import '../../../common/models/producto_models.dart';
import '../../../common/providers/auth_provider.dart';
import '../../../common/services/api_service.dart';

class MenuService {
  // ── Categorías ────────────────────────────────────────────────────────────

  static Future<List<CategoriaRead>> getCategorias({
    required String empresaId,
  }) async {
    final data = await ApiService.get(
        '/api/v1/categorias/?empresa_id=$empresaId&items_per_page=100&estado=activo');
    final list = (data['data'] ?? data['items']) as List<dynamic>;
    return list
        .map((i) => CategoriaRead.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  static Future<CategoriaRead> createCategoria(
      Map<String, dynamic> body) async {
    final data = await ApiService.post('/api/v1/categorias/', body);
    return CategoriaRead.fromJson(data);
  }

  static Future<CategoriaRead> updateCategoria(
      String id, Map<String, dynamic> body) async {
    final data = await ApiService.patch('/api/v1/categorias/$id', body);
    return CategoriaRead.fromJson(data);
  }

  static Future<void> deleteCategoria(String id) async {
    await ApiService.delete('/api/v1/categorias/$id');
  }

  // ── Productos ─────────────────────────────────────────────────────────────

  static Future<PaginatedProductos> getProductos({
    required String empresaId,
    int page = 1,
    int itemsPerPage = 50,
    String? categoriaId,
    String? search,
    String? estado,
  }) async {
    final params = StringBuffer(
        '/api/v1/productos/?empresa_id=$empresaId&page=$page&items_per_page=$itemsPerPage');
    if (categoriaId != null) params.write('&categoria_id=$categoriaId');
    if (search != null && search.isNotEmpty) params.write('&search=$search');
    if (estado != null) params.write('&estado=$estado');
    final data = await ApiService.get(params.toString());
    return PaginatedProductos.fromJson(data);
  }

  static Future<ProductoRead> createProducto(
      Map<String, dynamic> body) async {
    final data = await ApiService.post('/api/v1/productos/', body);
    return ProductoRead.fromJson(data);
  }

  static Future<ProductoRead> updateProducto(
      String id, Map<String, dynamic> body) async {
    final data = await ApiService.patch('/api/v1/productos/$id', body);
    return ProductoRead.fromJson(data);
  }

  static Future<void> deleteProducto(String id) async {
    await ApiService.delete('/api/v1/productos/$id');
  }

  // ── Producto × Sucursal ───────────────────────────────────────────────────

  static Future<ProductoSucursalRead> createProductoSucursal(
      String productoId, Map<String, dynamic> body) async {
    final data = await ApiService.post(
        '/api/v1/productos/$productoId/sucursales', body);
    return ProductoSucursalRead.fromJson(data);
  }

  static Future<ProductoSucursalRead> updateProductoSucursal(
      String psId, Map<String, dynamic> body) async {
    final data =
        await ApiService.patch('/api/v1/productos/sucursales/$psId', body);
    return ProductoSucursalRead.fromJson(data);
  }
}

class MenuProvider extends ChangeNotifier {
  List<CategoriaRead> categorias = [];
  List<ProductoRead> productos = [];
  int totalProductos = 0;
  bool isLoading = false;
  String? error;
  String? _categoriaFilter;
  String _searchQuery = '';

  AuthProvider? _auth;

  void init(AuthProvider auth) => _auth = auth;

  String? get empresaId => _auth?.isSuperAdmin == true
      ? _auth?.sucursalSeleccionada?.empresaId ?? _auth?.empresaId
      : _auth?.empresaId;

  String? get sucursalId => _auth?.isSuperAdmin == true
      ? _auth?.sucursalSeleccionada?.id
      : _auth?.sucursalId;

  String? get categoriaFilter => _categoriaFilter;

  Future<void> load({bool refresh = false}) async {
    if (empresaId == null) return;
    if (refresh) {
      categorias = [];
      productos = [];
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        MenuService.getCategorias(empresaId: empresaId!),
        MenuService.getProductos(
          empresaId: empresaId!,
          categoriaId: _categoriaFilter,
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
        ),
      ]);

      categorias = results[0] as List<CategoriaRead>;
      final paginado = results[1] as PaginatedProductos;
      productos = paginado.items;
      totalProductos = paginado.total;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Error al cargar el menú';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => load(refresh: true);

  void setCategoriaFilter(String? categoriaId) {
    _categoriaFilter = categoriaId;
    load(refresh: true);
  }

  void setSearch(String query) {
    _searchQuery = query;
    load(refresh: true);
  }
}

// Modelos adicionales que faltan en producto_models.dart
class PaginatedProductos {
  final List<ProductoRead> items;
  final int total;
  final int page;
  final int pages;

  const PaginatedProductos({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  factory PaginatedProductos.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] ?? json['items']) as List<dynamic>;
    return PaginatedProductos(
      items: list
          .map((i) => ProductoRead.fromJson(i as Map<String, dynamic>))
          .toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      pages: json['total_pages'] ?? json['pages'] ?? 1,
    );
  }
}