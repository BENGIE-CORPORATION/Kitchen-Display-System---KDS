import 'package:flutter/material.dart';
import '../../../common/models/models.dart';
import '../../../common/mock/mock_data.dart';
import '../../../common/services/api_service.dart';

// ─── Cambia a false cuando el BE esté listo ───────────────────────────────────
const bool useMock = true;

class MainAreaService {
  static Future<List<TableModel>> getTables() async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      return MainAreaMock.tables;
    }
    final data = await ApiService.get('/tables');
    return (data as List).map((j) => TableModel.fromJson(j)).toList();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
class MainAreaProvider extends ChangeNotifier {
  List<TableModel> tables = [];
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      tables = await MainAreaService.getTables();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}