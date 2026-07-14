import 'package:flutter/material.dart';
import '../../../common/models/mesa_models.dart';
import '../../../common/models/pedido_models.dart';
import '../../../common/models/producto_models.dart';
import '../../../common/providers/auth_provider.dart';
import '../../../common/services/api_service.dart';
import '../../../common/services/mesa_service.dart';
import '../../../common/services/pedido_service.dart';
import '../../../common/services/producto_catalog_service.dart';

/// Línea del carrito en construcción (aún no enviada al backend).
class CarritoLine {
  final ProductoSucursalRead producto;
  double cantidad;
  final List<VarianteRead> variantes;
  final String? notas;

  CarritoLine({
    required this.producto,
    this.cantidad = 1,
    this.variantes = const [],
    this.notas,
  });

  double get precioUnitario =>
      producto.precioVenta + variantes.fold(0.0, (s, v) => s + v.precioAdicional);
  double get subtotal => precioUnitario * cantidad;
  double get montoIva =>
      producto.aplicaIva ? subtotal * (producto.porcentajeIva / 100) : 0;
  double get montoServicio =>
      producto.aplicaServicio ? subtotal * (producto.porcentajeServicio / 100) : 0;
  double get total => subtotal + montoIva + montoServicio;

  Map<String, dynamic> toJson() => {
        'producto_id': producto.productoId,
        'cantidad': cantidad,
        'unidad_medida': producto.unidadMedida ?? 'unidad',
        'precio_unitario': precioUnitario,
        'descuento_porcentaje': 0,
        'descuento_monto': 0,
        'subtotal': subtotal,
        'iva': montoIva,
        'servicio': montoServicio,
        'total': total,
        if (variantes.isNotEmpty)
          'variantes_seleccionadas': {for (final v in variantes) v.id: v.nombre},
        if (notas != null && notas!.trim().isNotEmpty) 'notas': notas!.trim(),
      };
}

class PedidoBuilderProvider extends ChangeNotifier {
  final MesaRead mesa;
  PedidoBuilderProvider({required this.mesa});

  AuthProvider? _auth;

  PedidoReadDetalle? pedido;
  List<ProductoSucursalRead> productos = [];
  List<CategoriaRead> categorias = [];
  final List<CarritoLine> carritoNuevo = [];

  bool isLoading = true;
  bool isSending = false;
  String? error;

  String categoriaFiltro = 'Todas';
  String busqueda = '';

  String? get _sucursalId => _auth?.isSuperAdmin == true
      ? _auth?.sucursalSeleccionada?.id
      : _auth?.sucursalId;

  String? get _empresaId => _auth?.isSuperAdmin == true
      ? _auth?.sucursalSeleccionada?.empresaId ?? _auth?.empresaId
      : _auth?.empresaId;

  bool get esPedidoNuevo => pedido == null;

  Future<void> cargar(AuthProvider auth) async {
    _auth = auth;
    final sucursalId = _sucursalId;
    final empresaId = _empresaId;
    if (sucursalId == null || empresaId == null) {
      isLoading = false;
      error = 'No se pudo determinar la sucursal';
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final resultados = await Future.wait([
        ProductoCatalogService.getCatalogo(sucursalId),
        ProductoCatalogService.getCategorias(empresaId),
      ]);
      productos = resultados[0] as List<ProductoSucursalRead>;
      categorias = resultados[1] as List<CategoriaRead>;

      if (mesa.ocupada) {
        final activo = await MesaService.getPedidoActivo(mesa.id);
        if (activo != null) {
          pedido = await PedidoService.getPedidoDetalle(activo.id);
        }
      }
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Error al cargar el catálogo';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  List<ProductoSucursalRead> get productosFiltrados => productos.where((p) {
        final matchSearch = busqueda.isEmpty ||
            (p.nombre?.toLowerCase().contains(busqueda.toLowerCase()) ?? false);
        return matchSearch && p.disponibleVenta;
      }).toList();

  void setBusqueda(String q) {
    busqueda = q;
    notifyListeners();
  }

  Future<List<VarianteRead>> variantesDe(ProductoSucursalRead producto) {
    return ProductoCatalogService.getVariantes(producto.productoId);
  }

  void agregarAlCarrito(ProductoSucursalRead producto,
      {List<VarianteRead> variantes = const [], String? notas}) {
    carritoNuevo.add(CarritoLine(producto: producto, variantes: variantes, notas: notas));
    notifyListeners();
  }

  void quitarDelCarrito(int index) {
    carritoNuevo.removeAt(index);
    notifyListeners();
  }

  void incrementar(int index) {
    carritoNuevo[index].cantidad += 1;
    notifyListeners();
  }

  void decrementar(int index) {
    if (carritoNuevo[index].cantidad <= 1) {
      quitarDelCarrito(index);
    } else {
      carritoNuevo[index].cantidad -= 1;
      notifyListeners();
    }
  }

  double get subtotal => carritoNuevo.fold(0, (s, i) => s + i.subtotal);
  double get totalIva => carritoNuevo.fold(0, (s, i) => s + i.montoIva);
  double get totalServicio => carritoNuevo.fold(0, (s, i) => s + i.montoServicio);
  double get total => subtotal + totalIva + totalServicio;

  /// Crea el pedido (si es nuevo) o agrega los ítems al pedido existente,
  /// y lo pasa a "abierto" para que aparezca en Kitchen Display.
  Future<bool> enviarACocina() async {
    if (carritoNuevo.isEmpty) {
      error = 'Agrega al menos un producto';
      notifyListeners();
      return false;
    }

    isSending = true;
    error = null;
    notifyListeners();

    try {
      if (pedido == null) {
        final numero =
            'M${mesa.numero}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
        final nuevo = await PedidoService.createPedido({
          'empresa_id': _empresaId,
          'sucursal_id': _sucursalId,
          'mesa_id': mesa.id,
          'numero_pedido': numero,
          'tipo_pedido': 'mesa',
          'canal_venta': 'presencial',
          'items': carritoNuevo.map((i) => i.toJson()).toList(),
        });
        await PedidoService.cambiarEstado(nuevo.id, 'abierto');
        await MesaService.cambiarEstado(mesa.id, 'ocupada');
        pedido = await PedidoService.getPedidoDetalle(nuevo.id);
      } else {
        for (final item in carritoNuevo) {
          await PedidoService.addItem(pedido!.id, item.toJson());
        }
        pedido = await PedidoService.getPedidoDetalle(pedido!.id);
      }
      carritoNuevo.clear();
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'Error al enviar el pedido a cocina';
      return false;
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  Future<void> refrescarPedido() async {
    if (pedido == null) return;
    pedido = await PedidoService.getPedidoDetalle(pedido!.id);
    notifyListeners();
  }
}
