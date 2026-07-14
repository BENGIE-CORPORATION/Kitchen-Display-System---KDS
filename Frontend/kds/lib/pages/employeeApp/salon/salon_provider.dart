import 'package:flutter/material.dart';
import '../../../common/models/mesa_models.dart';
import '../../../common/providers/auth_provider.dart';
import '../../../common/services/api_service.dart';
import '../../../common/services/mesa_service.dart';

class SalonProvider extends ChangeNotifier {
  List<MesaRead> mesas = [];
  bool isLoading = false;
  String? error;

  AuthProvider? _auth;

  void init(AuthProvider auth) => _auth = auth;

  String? get _sucursalId => _auth?.isSuperAdmin == true
      ? _auth?.sucursalSeleccionada?.id
      : _auth?.sucursalId;

  Future<void> load({bool refresh = false}) async {
    final sucursalId = _sucursalId;
    if (sucursalId == null) return;
    if (refresh) mesas = [];

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final result = await MesaService.getMesas(sucursalId);
      mesas = result.items..sort((a, b) => a.numero.compareTo(b.numero));
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Error al cargar las mesas';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reload() => load(refresh: true);

  int get ocupadas => mesas.where((m) => m.ocupada).length;
}
