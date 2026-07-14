import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/models/producto_models.dart';
import '../../../common/services/mesa_service.dart';
import '../../../common/services/pedido_service.dart';
import '../../adminPanel/sales/widgets/pago_modal.dart';
import '../../adminPanel/caja/caja_provider.dart' show CajaService;
import 'pedido_builder_provider.dart';
import 'widgets/variante_picker_sheet.dart';

/// Pantalla completa de construcción de pedido para una mesa: catálogo +
/// carrito nuevo + ticket ya enviado a cocina + cobro.
class PedidoBuilderPage extends StatefulWidget {
  final PedidoBuilderProvider provider;
  final VoidCallback onBack;
  final VoidCallback onFacturado;

  const PedidoBuilderPage({
    super.key,
    required this.provider,
    required this.onBack,
    required this.onFacturado,
  });

  @override
  State<PedidoBuilderPage> createState() => _PedidoBuilderPageState();
}

class _PedidoBuilderPageState extends State<PedidoBuilderPage> {
  final _searchCtrl = TextEditingController();
  bool _cobrando = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onProductoTap(ProductoSucursalRead producto) async {
    final provider = widget.provider;
    final variantes = await provider.variantesDe(producto);

    if (!mounted) return;

    if (variantes.isEmpty) {
      provider.agregarAlCarrito(producto);
      return;
    }

    final resultado = await showVariantePicker(
      context,
      nombreProducto: producto.nombre ?? 'Producto',
      variantes: variantes,
    );
    if (resultado != null) {
      provider.agregarAlCarrito(producto,
          variantes: resultado.variantes, notas: resultado.notas);
    }
  }

  Future<void> _enviarACocina() async {
    final ok = await widget.provider.enviarACocina();
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido enviado a cocina')));
    } else if (widget.provider.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(widget.provider.error!)));
    }
  }

  Future<void> _cobrar() async {
    final pedido = widget.provider.pedido;
    if (pedido == null) return;

    setState(() => _cobrando = true);
    try {
      final sucursalId = pedido.sucursalId;
      final cajas = await CajaService.getCajas(sucursalId, estado: 'activo');
      String? sesionCajaId;
      for (final caja in cajas.items) {
        final sesion = await CajaService.getSesionActiva(caja.id);
        if (sesion != null) {
          sesionCajaId = sesion.id;
          break;
        }
      }

      if (!mounted) return;
      if (sesionCajaId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No hay una sesión de caja abierta. Pide al cajero que abra caja para poder cobrar.')));
        return;
      }

      await showDialog(
        context: context,
        builder: (_) => PagoModal(
          pedido: pedido,
          sesionCajaId: sesionCajaId!,
          onSuccess: () async {
            await PedidoService.cambiarEstado(pedido.id, 'facturado',
                sesionCajaId: sesionCajaId);
            await MesaService.cambiarEstado(pedido.mesaId!, 'libre');
            if (mounted) widget.onFacturado();
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _cobrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.provider,
      child: Consumer<PedidoBuilderProvider>(
        builder: (context, provider, _) => Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          body: SafeArea(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: widget.onBack,
                              icon: const Icon(Icons.arrow_back),
                            ),
                            Text('Mesa ${provider.mesa.numero}',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111827))),
                            if (provider.pedido != null) ...[
                              const SizedBox(width: 8),
                              Text('· Pedido #${provider.pedido!.numeroPedido}',
                                  style: const TextStyle(
                                      fontSize: 13, color: Color(0xFF6B7280))),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (provider.error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(provider.error!,
                                style: const TextStyle(color: Color(0xFFDC2626))),
                          ),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _Catalogo(provider: provider, onTap: _onProductoTap)),
                              const SizedBox(width: 20),
                              SizedBox(
                                width: 320,
                                child: _Panel(
                                  provider: provider,
                                  cobrando: _cobrando,
                                  onEnviar: _enviarACocina,
                                  onCobrar: _cobrar,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Catalogo extends StatelessWidget {
  final PedidoBuilderProvider provider;
  final ValueChanged<ProductoSucursalRead> onTap;
  const _Catalogo({required this.provider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: provider.setBusqueda,
          decoration: InputDecoration(
            hintText: 'Buscar producto...',
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: provider.productosFiltrados.length,
            itemBuilder: (_, i) {
              final p = provider.productosFiltrados[i];
              return _ProductoTile(producto: p, onTap: () => onTap(p));
            },
          ),
        ),
      ],
    );
  }
}

class _ProductoTile extends StatelessWidget {
  final ProductoSucursalRead producto;
  final VoidCallback onTap;
  const _ProductoTile({required this.producto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(producto.nombre ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827))),
            const SizedBox(height: 4),
            Text('₡${producto.precioVenta.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final PedidoBuilderProvider provider;
  final bool cobrando;
  final VoidCallback onEnviar;
  final VoidCallback onCobrar;

  const _Panel({
    required this.provider,
    required this.cobrando,
    required this.onEnviar,
    required this.onCobrar,
  });

  @override
  Widget build(BuildContext context) {
    final pedido = provider.pedido;
    final puedeFacturar = pedido?.puedeFacturar ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pedido != null) ...[
            Text('Ya enviado a cocina (${pedido.estado})',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151))),
            const SizedBox(height: 8),
            ...pedido.items.where((i) => !i.cancelado).map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${i.cantidad.toStringAsFixed(0)}× —  ₡${i.total.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                )),
            const Divider(height: 24),
          ],
          Text('Carrito nuevo (${provider.carritoNuevo.length})',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          const SizedBox(height: 8),
          Expanded(
            child: provider.carritoNuevo.isEmpty
                ? const Center(
                    child: Text('Toca un producto para agregarlo',
                        style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))))
                : ListView.builder(
                    itemCount: provider.carritoNuevo.length,
                    itemBuilder: (_, i) {
                      final item = provider.carritoNuevo[i];
                      return _CarritoTile(
                        item: item,
                        onIncrementar: () => provider.incrementar(i),
                        onDecrementar: () => provider.decrementar(i),
                      );
                    },
                  ),
          ),
          if (provider.carritoNuevo.isNotEmpty) ...[
            const Divider(),
            _TotalRow('Total', provider.total, bold: true),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: provider.isSending ? null : onEnviar,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: provider.isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Enviar a cocina'),
              ),
            ),
          ],
          if (puedeFacturar) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: cobrando ? null : onCobrar,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: cobrando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Cobrar'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CarritoTile extends StatelessWidget {
  final dynamic item;
  final VoidCallback onIncrementar;
  final VoidCallback onDecrementar;

  const _CarritoTile({
    required this.item,
    required this.onIncrementar,
    required this.onDecrementar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(item.producto.nombre ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          IconButton(
            onPressed: onDecrementar,
            icon: const Icon(Icons.remove_circle_outline, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Text('${item.cantidad.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 13)),
          IconButton(
            onPressed: onIncrementar,
            icon: const Icon(Icons.add_circle_outline, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  const _TotalRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text('₡${value.toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}
