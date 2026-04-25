import 'package:flutter/material.dart';
import '../../../../common/models/pedido_models.dart';
import '../../../../common/models/pago_models.dart';
import '../../../../common/services/api_service.dart';
import '../sales_provider.dart';

class PedidoDetalleModal extends StatefulWidget {
  final PedidoRead pedido;
  final String? sesionCajaId;
  final VoidCallback onSuccess;

  const PedidoDetalleModal({
    super.key,
    required this.pedido,
    this.sesionCajaId,
    required this.onSuccess,
  });

  @override
  State<PedidoDetalleModal> createState() => _PedidoDetalleModalState();
}

class _PedidoDetalleModalState extends State<PedidoDetalleModal> {
  bool _isLoading = true;
  String? _error;
  PedidoReadDetalle? _detalle;
  List<PagoRead> _pagos = [];

  @override
  void initState() {
    super.initState();
    _loadDetalle();
  }

  Future<void> _loadDetalle() async {
    try {
      final detalle = await SalesService.getPedidoDetalle(widget.pedido.id);
      final pagos = await SalesService.getPagosPedido(widget.pedido.id);
      if (!mounted) return;
      setState(() {
        _detalle = detalle;
        _pagos = pagos;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Error al cargar el detalle'; _isLoading = false; });
    }
  }

  void _close() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  static const _labelsEstado = {
    'borrador': 'Borrador',
    'abierto': 'Abierto',
    'en_preparacion': 'En preparación',
    'listo': 'Listo',
    'en_entrega': 'En entrega',
    'entregado': 'Entregado',
    'facturado': 'Facturado',
    'cancelado': 'Cancelado',
  };

  static const _labelsMetodo = {
    'efectivo': 'Efectivo',
    'tarjeta_debito': 'Tarjeta débito',
    'tarjeta_credito': 'Tarjeta crédito',
    'transferencia': 'Transferencia',
    'sinpe': 'SINPE',
    'cheque': 'Cheque',
    'credito': 'Crédito',
    'otros': 'Otros',
  };

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final p = widget.pedido;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: sw > 680 ? 640 : sw - 48,
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
                          'Pedido ${p.numeroPedido}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827)),
                        ),
                        Row(
                          children: [
                            _estadoBadge(p.estado),
                            const SizedBox(width: 8),
                            _pagoBadge(p.estadoPago),
                          ],
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
                const Expanded(
                  child: Center(
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
                        // Info del cliente
                        if (p.nombreCliente != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person_outline,
                                    size: 16, color: Color(0xFF6B7280)),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.nombreCliente!,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF111827))),
                                    if (p.telefonoCliente != null)
                                      Text(p.telefonoCliente!,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF6B7280))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Ítems
                        const Text('Productos',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151))),
                        const SizedBox(height: 8),

                        for (final item in _detalle!.items)
                          _buildItemRow(item),

                        // Totales
                        const Divider(color: Color(0xFFE5E7EB), height: 24),
                        _TotalRow('Subtotal', _detalle!.subtotal),
                        _TotalRow('IVA', _detalle!.totalIva),
                        _TotalRow('Servicio', _detalle!.totalServicio),
                        if (_detalle!.propina > 0)
                          _TotalRow('Propina', _detalle!.propina),
                        if (_detalle!.descuentoMonto > 0)
                          _TotalRow('Descuento', -_detalle!.descuentoMonto,
                              color: const Color(0xFF16A34A)),
                        const Divider(color: Color(0xFFE5E7EB), height: 16),
                        _TotalRow('Total', _detalle!.total,
                            bold: true, large: true),

                        // Pagos registrados
                        if (_pagos.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text('Pagos registrados',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF374151))),
                          const SizedBox(height: 8),
                          for (final pago in _pagos) _buildPagoRow(pago),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFBBF7D0)),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total pagado',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF15803D))),
                                Text(
                                  '₡${_pagos.where((p) => p.estado == 'completado').fold(0.0, (s, p) => s + p.monto).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF16A34A)),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (p.motivoCancelacion != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.cancel_outlined,
                                    size: 16, color: Color(0xFFDC2626)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Motivo de cancelación: ${p.motivoCancelacion}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFFDC2626)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),
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

  Widget _buildItemRow(DetallePedidoRead item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          if (item.cancelado)
            const Icon(Icons.cancel, size: 14, color: Color(0xFFDC2626))
          else
            const Icon(Icons.check_circle_outline,
                size: 14, color: Color(0xFF16A34A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${item.cantidad} × producto',
              style: TextStyle(
                fontSize: 13,
                color: item.cancelado
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF111827),
                decoration: item.cancelado
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
          Text(
            '₡${item.total.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: item.cancelado
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagoRow(PagoRead pago) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined,
              size: 14, color: Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _labelsMetodo[pago.metodoPago] ?? pago.metodoPago,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF374151)),
            ),
          ),
          Text(
            '₡${pago.monto.toStringAsFixed(2)}',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827)),
          ),
          if (pago.cambio != null && pago.cambio! > 0) ...[
            const SizedBox(width: 8),
            Text(
              '(cambio: ₡${pago.cambio!.toStringAsFixed(2)})',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _estadoBadge(String estado) {
    final colors = const {
      'borrador': (Color(0xFF6B7280), Color(0xFFF3F4F6)),
      'abierto': (Color(0xFF2563EB), Color(0xFFEFF6FF)),
      'en_preparacion': (Color(0xFFD97706), Color(0xFFFFFBEB)),
      'listo': (Color(0xFF16A34A), Color(0xFFF0FDF4)),
      'en_entrega': (Color(0xFF7C3AED), Color(0xFFF5F3FF)),
      'entregado': (Color(0xFF16A34A), Color(0xFFF0FDF4)),
      'facturado': (Color(0xFF16A34A), Color(0xFFF0FDF4)),
      'cancelado': (Color(0xFFDC2626), Color(0xFFFEE2E2)),
    };
    final c = colors[estado] ??
        (const Color(0xFF6B7280), const Color(0xFFF3F4F6));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: c.$2, borderRadius: BorderRadius.circular(12)),
      child: Text(_labelsEstado[estado] ?? estado,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: c.$1)),
    );
  }

  Widget _pagoBadge(String estado) {
    final colors = const {
      'pendiente': (Color(0xFFD97706), Color(0xFFFFFBEB)),
      'pagado': (Color(0xFF16A34A), Color(0xFFF0FDF4)),
      'pago_parcial': (Color(0xFF2563EB), Color(0xFFEFF6FF)),
      'credito': (Color(0xFF7C3AED), Color(0xFFF5F3FF)),
    };
    final c = colors[estado] ??
        (const Color(0xFF6B7280), const Color(0xFFF3F4F6));
    final labels = const {
      'pendiente': 'Pendiente',
      'pagado': 'Pagado',
      'pago_parcial': 'Parcial',
      'credito': 'Crédito',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: c.$2, borderRadius: BorderRadius.circular(12)),
      child: Text(labels[estado] ?? estado,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: c.$1)),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  final bool large;
  final Color? color;

  const _TotalRow(this.label, this.value,
      {this.bold = false, this.large = false, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF111827);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: large ? 14 : 13,
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal,
                  color: const Color(0xFF374151))),
          Text(
            '₡${value.abs().toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: large ? 15 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: c),
          ),
        ],
      ),
    );
  }
}