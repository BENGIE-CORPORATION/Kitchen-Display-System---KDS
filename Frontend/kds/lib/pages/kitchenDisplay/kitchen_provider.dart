import 'dart:async';
import 'package:flutter/material.dart';
import '../../common/models/pedido_models.dart';
import '../../common/models/mesa_models.dart';
import '../../common/providers/auth_provider.dart';
import '../../common/services/api_service.dart';
import '../../common/services/pedido_service.dart';
import '../../common/services/mesa_service.dart';
import '../../common/services/producto_catalog_service.dart';

/// Estados que se muestran en el tablero de cocina (se excluyen
/// borrador/entregado/facturado/cancelado — ya no requieren acción de cocina).
const kEstadosTablero = ['abierto', 'en_preparacion', 'listo'];

class KitchenProvider extends ChangeNotifier {
  List<PedidoReadDetalle> pedidos = [];
  Map<String, MesaRead> mesasPorId = {};
  ProductoNombreResolver? resolver;
  bool isLoading = false;
  String? error;
  String filtro = 'todos'; // todos | abierto | en_preparacion | listo

  AuthProvider? _auth;
  Timer? _timer;

  void init(AuthProvider auth) => _auth = auth;

  String? get _empresaId => _auth?.isSuperAdmin == true
      ? _auth?.sucursalSeleccionada?.empresaId ?? _auth?.empresaId
      : _auth?.empresaId;

  String? get _sucursalId => _auth?.isSuperAdmin == true
      ? _auth?.sucursalSeleccionada?.id
      : _auth?.sucursalId;

  void start() {
    _loadEstatico();
    _loadPedidos();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _loadPedidos());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Catálogo y mesas cambian poco — se cargan una vez, no en cada poll.
  Future<void> _loadEstatico() async {
    final sucursalId = _sucursalId;
    if (sucursalId == null) return;
    try {
      final catalogo = await ProductoCatalogService.getCatalogo(
          sucursalId, soloDisponibles: false);
      final mesas = await MesaService.getMesas(sucursalId);
      resolver = ProductoNombreResolver(catalogo);
      mesasPorId = {for (final m in mesas.items) m.id: m};
      notifyListeners();
    } catch (_) {
      // no bloquea el tablero si falla — solo se pierde el nombre/mesa amigable
    }
  }

  Future<void> _loadPedidos() async {
    final empresaId = _empresaId;
    if (empresaId == null) return;

    isLoading = pedidos.isEmpty;
    error = null;
    notifyListeners();

    try {
      final result = await PedidoService.getPedidos(
        empresaId: empresaId,
        sucursalId: _sucursalId,
        itemsPerPage: 200,
      );
      final activos =
          result.items.where((p) => kEstadosTablero.contains(p.estado)).toList();

      // El endpoint de lista no trae items — se pide el detalle de cada
      // pedido activo para poder renderizar la comanda completa.
      final detalles = await Future.wait(
        activos.map((p) => PedidoService.getPedidoDetalle(p.id)),
      );
      detalles.sort((a, b) =>
          (a.fechaPedido ?? DateTime.now()).compareTo(b.fechaPedido ?? DateTime.now()));
      pedidos = detalles;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Error al cargar los pedidos';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAhora() => _loadPedidos();

  void setFiltro(String f) {
    filtro = f;
    notifyListeners();
  }

  List<PedidoReadDetalle> get pedidosFiltrados {
    if (filtro == 'todos') return pedidos;
    return pedidos.where((p) => p.estado == filtro).toList();
  }

  int get countNuevos => pedidos.where((p) => p.estado == 'abierto').length;
  int get countEnPreparacion =>
      pedidos.where((p) => p.estado == 'en_preparacion').length;
  int get countListos => pedidos.where((p) => p.estado == 'listo').length;

  /// Próximo estado a aplicar al tocar el botón de acción de la tarjeta.
  String? siguienteEstado(String estadoActual) {
    switch (estadoActual) {
      case 'abierto':
        return 'en_preparacion';
      case 'en_preparacion':
        return 'listo';
      case 'listo':
        return 'entregado';
      default:
        return null;
    }
  }

  Future<void> avanzarEstado(PedidoReadDetalle pedido) async {
    final siguiente = siguienteEstado(pedido.estado);
    if (siguiente == null) return;
    try {
      await PedidoService.cambiarEstado(pedido.id, siguiente);
      await _loadPedidos();
    } on ApiException catch (e) {
      error = e.message;
      notifyListeners();
    }
  }
}
