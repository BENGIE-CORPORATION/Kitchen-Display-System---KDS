import 'package:flutter/material.dart';
import '../../../common/models/models.dart';
import '../../../common/mock/mock_data.dart';
import '../../../common/services/api_service.dart';

// ─── Cambia a false cuando el BE esté listo ───────────────────────────────────
const bool useMock = true;

class SalesService {
  static Future<List<Product>> getProducts() async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      return SalesMock.products;
    }
    final data = await ApiService.get('/products');
    return (data as List).map((j) => Product.fromJson(j)).toList();
  }

  static Future<void> processSale({
    required List<SaleItem> items,
    required String cliente,
  }) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      return;
    }
    await ApiService.post('/sales', {
      'cliente': cliente,
      'items': items.map((i) => {
        'clave': i.clave,
        'cantidad': i.cantidad,
        'precio': i.precio,
      }).toList(),
    });
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
class SalesProvider extends ChangeNotifier {
  List<Product> products = [];
  List<SaleItem> currentItems = [];
  String cliente = '';
  bool isLoading = false;
  bool isProcessing = false;
  String? error;

  Future<void> loadProducts() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      products = await SalesService.getProducts();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void addProduct(Product product) {
    final idx = currentItems.indexWhere((i) => i.clave == product.clave);
    if (idx >= 0) {
      currentItems[idx].cantidad++;
    } else {
      currentItems.add(SaleItem(
        id: UniqueKey().toString(),
        clave: product.clave,
        nombre: product.nombre,
        cantidad: 1,
        precio: product.precio,
      ));
    }
    notifyListeners();
  }

  void changeQty(String id, int delta) {
    final idx = currentItems.indexWhere((i) => i.id == id);
    if (idx >= 0) {
      final newQty = currentItems[idx].cantidad + delta;
      if (newQty < 1) return;
      currentItems[idx].cantidad = newQty;
      notifyListeners();
    }
  }

  void removeItem(String id) {
    currentItems.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  void setCliente(String value) {
    cliente = value;
    notifyListeners();
  }

  void clearSale() {
    currentItems.clear();
    cliente = '';
    notifyListeners();
  }

  Future<bool> processSale() async {
    if (currentItems.isEmpty) return false;
    isProcessing = true;
    notifyListeners();

    try {
      await SalesService.processSale(items: currentItems, cliente: cliente);
      clearSale();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  double get total =>
      currentItems.fold(0, (sum, i) => sum + i.total);

  int get totalItems =>
      currentItems.fold(0, (sum, i) => sum + i.cantidad);
}