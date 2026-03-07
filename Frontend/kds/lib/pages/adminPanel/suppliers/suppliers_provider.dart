import 'package:flutter/material.dart';
import '../../../common/models/models.dart';
import '../../../common/mock/mock_data.dart';
import '../../../common/services/api_service.dart';

// ─── Cambia a false cuando el BE esté listo ───────────────────────────────────
const bool useMock = true;

class SuppliersService {
  static Future<List<Supplier>> getSuppliers() async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      return SuppliersMock.suppliers;
    }
    final data = await ApiService.get('/suppliers');
    return (data as List).map((j) => Supplier.fromJson(j)).toList();
  }

  static Future<Map<String, dynamic>> getKpis() async {
    if (useMock) return {};
    return await ApiService.get('/suppliers/kpis');
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
class SuppliersProvider extends ChangeNotifier {
  List<Supplier> suppliers = [];
  Map<String, dynamic> kpis = {};
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        SuppliersService.getSuppliers(),
        SuppliersService.getKpis(),
      ]);
      suppliers = results[0] as List<Supplier>;
      kpis = results[1] as Map<String, dynamic>;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}