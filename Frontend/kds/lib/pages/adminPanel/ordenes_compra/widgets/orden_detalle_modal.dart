import 'package:flutter/material.dart';
import '../../../../../common/models/orden_compra_models.dart';
import '../../../../../common/services/api_service.dart';
import '../ordenes_compra_provider.dart';

class OrdenDetalleModal extends StatefulWidget {
  final OrdenCompraRead orden;
  final VoidCallback onSuccess;

  const OrdenDetalleModal({
    super.key,
    required this.orden,
    required this.onSuccess,
  });

  @override
  State<OrdenDetalleModal> createState() => _OrdenDetalleModalState();
}

class _OrdenDetalleModalState extends State<OrdenDetalleModal> {
  bool _isLoading = true;
  String? _error;
  OrdenCompraReadDetalle? _detalle;

  // Controllers para recepción por ítem
  final Map<String, TextEditingController> _recepcionCtrls = {};

  @override
  void initState() {
    super.initState();
    _loadDetalle();
  }

  @override
  void dispose() {
    for (final c in _recepcionCtrls.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadDetalle() async {
    try {
      final detalle =
          await OrdenesCompraService.getOrdenDetalle(widget.orden.id);
      if (!mounted) return;
      // Inicializar controllers de recepción para cada ítem
      for (final item in detalle.items) {
        _recepcionCtrls[item.id] = TextEditingController(
          text: item.cantidadRecibida.toStringAsFixed(3),
        );
      }
      setState(() { _detalle = detalle; _isLoading = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al cargar el detalle';
        _isLoading = false;
      });
    }
  }

  void _close() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _registrarRecepcion(DetalleOrdenRead item) async {
    final ctrl = _recepcionCtrls[item.id];
    final cantidad = double.tryParse(ctrl?.text ?? '');

    if (cantidad == null || cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa una cantidad válida mayor a 0')),
      );
      return;
    }
    if (cantidad > item.cantidadSolicitada) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'La cantidad no puede superar la solicitada (${item.cantidadSolicitada})'),
        ),
      );
      return;
    }

    try {
      await OrdenesCompraService.registrarRecepcionItem(
        ordenId: widget.orden.id,
        itemId: item.id,
        cantidadRecibida: cantidad,
      );
      await _loadDetalle();
      widget.onSuccess();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: sw > 700 ? 660 : sw - 48,
          maxHeight: sh * 0.92,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Orden ${widget.orden.numeroOrden}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827)),
                        ),
                        Text(
                          _labelEstado(widget.orden.estado),
                          style: TextStyle(
                              fontSize: 12,
                              color: _colorEstado(widget.orden.estado)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _close,
                    icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(
                        color: Color(0xFF2563EB)),
                  ),
                )
              else if (_error != null)
                Center(
                  child: Text(_error!,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFFDC2626))),
                )
              else if (_detalle != null)
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Resumen de totales
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              _totalItem('Subtotal',
                                  '₡${_formatMoney(_detalle!.subtotal)}'),
                              _totalItem('Impuestos',
                                  '₡${_formatMoney(_detalle!.impuestos)}'),
                              _totalItem('Descuentos',
                                  '₡${_formatMoney(_detalle!.descuentos)}'),
                              _totalItem(
                                'Total',
                                '₡${_formatMoney(_detalle!.total)}',
                                bold: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Ítems
                        const Text('Ítems de la orden',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151))),
                        const SizedBox(height: 12),

                        for (final item in _detalle!.items) ...[
                          _buildItemCard(item),
                          const SizedBox(height: 8),
                        ],

                        if (_detalle!.notas != null) ...[
                          const SizedBox(height: 16),
                          const Text('Notas',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151))),
                          const SizedBox(height: 6),
                          Text(
                            _detalle!.notas!,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _close,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(DetalleOrdenRead item) {
    final puedeRecibirItems = widget.orden.puedeRecibirItems;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.recibidoCompleto
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: item.recibidoCompleto
              ? const Color(0xFFBBF7D0)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.cantidadSolicitada} ${item.unidadMedida}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827)),
                    ),
                    Text(
                      'P.U: ₡${_formatMoney(item.precioUnitario)} · Subtotal: ₡${_formatMoney(item.subtotal)}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              if (item.recibidoCompleto)
                const Icon(Icons.check_circle,
                    color: Color(0xFF16A34A), size: 18),
            ],
          ),

          // Recepción — solo cuando el estado lo permite
          if (puedeRecibirItems) ...[
            const SizedBox(height: 10),
            const Divider(color: Color(0xFFE5E7EB), height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recibido: ${item.cantidadRecibida} / ${item.cantidadSolicitada}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 36,
                        child: TextField(
                          controller: _recepcionCtrls[item.id],
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF111827)),
                          decoration: InputDecoration(
                            hintText: 'Cantidad recibida',
                            hintStyle: const TextStyle(
                                color: Color(0xFF9CA3AF), fontSize: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                    color: Color(0xFFD1D5DB))),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                    color: Color(0xFFD1D5DB))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(
                                    color: Color(0xFF2563EB), width: 2)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: item.recibidoCompleto
                      ? null
                      : () => _registrarRecepcion(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Registrar',
                      style: TextStyle(
                          color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _totalItem(String label, String value, {bool bold = false}) =>
      Expanded(
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF6B7280))),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: const Color(0xFF111827))),
          ],
        ),
      );

  String _formatMoney(double v) => v
      .toStringAsFixed(2)
      .replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  String _labelEstado(String estado) => const {
        'borrador': 'Borrador',
        'enviada': 'Enviada',
        'confirmada': 'Confirmada',
        'parcial': 'Recepción parcial',
        'recibida': 'Recibida',
        'cancelada': 'Cancelada',
      }[estado] ??
      estado;

  Color _colorEstado(String estado) => const {
        'borrador': Color(0xFF6B7280),
        'enviada': Color(0xFF2563EB),
        'confirmada': Color(0xFF16A34A),
        'parcial': Color(0xFFD97706),
        'recibida': Color(0xFF16A34A),
        'cancelada': Color(0xFFDC2626),
      }[estado] ??
      const Color(0xFF6B7280);
}