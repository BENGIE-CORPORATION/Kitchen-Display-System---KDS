import 'package:flutter/material.dart';
import '../../../common/models/models.dart';
import '../../../common/mock/mock_data.dart';
import '../../../common/services/api_service.dart';

// ─── Cambia a false cuando el BE esté listo ───────────────────────────────────
const bool useMock = true;

class InventoryService {
  static Future<List<InventoryItem>> getItems() async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      return InventoryMock.items;
    }
    final data = await ApiService.get('/inventory');
    return (data as List).map((j) => InventoryItem.fromJson(j)).toList();
  }

  static Future<void> adjustItem(String id, double newStock) async {
    if (useMock) return;
    await ApiService.post('/inventory/$id/adjust', {'stock': newStock});
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
class InventoryProvider extends ChangeNotifier {
  List<InventoryItem> items = [];
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      items = await InventoryService.getItems();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> adjust(String id, double newStock) async {
    await InventoryService.adjustItem(id, newStock);
    await load(); // refresca la lista
  }
}