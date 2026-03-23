import 'package:flutter/material.dart';
import '../../../common/models/materia_prima_models.dart';
import '../../../common/services/api_service.dart';

// ─── Service ──────────────────────────────────────────────────────────────────
class InventoryService {
  /// GET /materias-primas/sucursal/{sucursal_id}
  static Future<PaginatedMateriaPrimas> getMaterisPrimasPorSucursal({
    required String sucursalId,
    int page = 1,
    int itemsPerPage = 50,
    bool bajoMinimo = false,
  }) async {
    final query = '/materias-primas/sucursal/$sucursalId'
        '?page=$page'
        '&items_per_page=$itemsPerPage'
        '&bajo_minimo=$bajoMinimo';

    final data = await ApiService.get(query);
    return PaginatedMateriaPrimas.fromJson(data);
  }

  /// PATCH /materias-primas/sucursales/{mps_id}
  static Future<void> ajustarStock({
    required String mpsId,
    required double nuevoStock,
  }) async {
    await ApiService.patch(
      '/materias-primas/sucursales/$mpsId',
      {'stock_actual': nuevoStock},
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
class InventoryProvider extends ChangeNotifier {
  List<MateriaPrimaSucursalRead> items = [];
  int total = 0;
  bool isLoading = false;
  String? error;

  String? _sucursalId;

  Future<void> load(String sucursalId, {bool refresh = false}) async {
    _sucursalId = sucursalId;

    if (refresh) items = [];

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final result = await InventoryService.getMaterisPrimasPorSucursal(
        sucursalId: sucursalId,
      );
      items = result.items;
      total = result.total;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Error al cargar el inventario';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> ajustarStock(String mpsId, double nuevoStock) async {
    try {
      await InventoryService.ajustarStock(mpsId: mpsId, nuevoStock: nuevoStock);
      if (_sucursalId != null) await load(_sucursalId!, refresh: true);
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
    }
  }

  /// Filtra localmente sin llamar al BE
  List<MateriaPrimaSucursalRead> filtrar({
    String query = '',
    String categoria = 'Todas',
    bool soloBajoMinimo = false,
  }) {
    return items.where((item) {
      final q = query.toLowerCase();
      final matchSearch = q.isEmpty ||
          (item.nombre?.toLowerCase().contains(q) ?? false) ||
          (item.codigo?.toLowerCase().contains(q) ?? false) ||
          (item.categoria?.toLowerCase().contains(q) ?? false);
      final matchCat = categoria == 'Todas' || item.categoria == categoria;
      final matchBajo = !soloBajoMinimo || item.isBajoMinimo;
      return matchSearch && matchCat && matchBajo;
    }).toList();
  }

  /// Categorías únicas extraídas dinámicamente de los datos
  List<String> get categorias {
    final cats = items
        .map((i) => i.categoria ?? 'Sin categoría')
        .toSet()
        .toList()
      ..sort();
    return ['Todas', ...cats];
  }

  int get totalBajoMinimo => items.where((i) => i.isBajoMinimo).length;
}