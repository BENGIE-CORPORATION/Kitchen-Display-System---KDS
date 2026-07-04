import 'package:flutter/material.dart';
import '../../../../common/models/pedido_models.dart';
import '../../../../common/services/api_service.dart';
import '../sales_provider.dart';

class PagoModal extends StatefulWidget {
  final PedidoRead pedido;
  final String sesionCajaId;
  final VoidCallback onSuccess;

  const PagoModal({
    super.key,
    required this.pedido,
    required this.sesionCajaId,
    required this.onSuccess,
  });

  @override
  State<PagoModal> createState() => _PagoModalState();
}

class _PagoModalState extends State<PagoModal> {
  bool _isLoading = false;
  String? _error;

  String _metodoPago = 'efectivo';
  final _montoCtrl         = TextEditingController();
  final _montoRecibidoCtrl = TextEditingController();
  final _numeroCtrl        = TextEditingController();
  final _referenciaCtrl    = TextEditingController();
  final _ultimos4Ctrl      = TextEditingController();

  static const _metodos = [
    'efectivo', 'tarjeta_debito', 'tarjeta_credito',
    'transferencia', 'sinpe', 'cheque', 'credito', 'otros',
  ];

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
  void initState() {
    super.initState();
    // Pre-llenar con el total pendiente del pedido
    _montoCtrl.text = widget.pedido.total.toStringAsFixed(2);
    // Número de pago autogenerado
    _numeroCtrl.text =
        'PAG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _montoRecibidoCtrl.dispose();
    _numeroCtrl.dispose();
    _referenciaCtrl.dispose();
    _ultimos4Ctrl.dispose();
    super.dispose();
  }

  void _close({bool success = false}) {
    if (!mounted) return;
    Navigator.of(context).pop();
    if (success) widget.onSuccess();
  }

  double get _cambio {
    final monto = double.tryParse(_montoCtrl.text) ?? 0;
    final recibido = double.tryParse(_montoRecibidoCtrl.text) ?? 0;
    return (recibido - monto).clamp(0, double.infinity);
  }

  Future<void> _registrar() async {
    final monto = double.tryParse(_montoCtrl.text);
    if (monto == null || monto <= 0)
      return setState(() => _error = 'El monto debe ser mayor a 0');
    if (_numeroCtrl.text.trim().isEmpty)
      return setState(() => _error = 'El número de pago es requerido');
    if (_metodoPago == 'efectivo') {
      final recibido = double.tryParse(_montoRecibidoCtrl.text);
      if (recibido == null || recibido < monto)
        return setState(
            () => _error = 'El monto recibido no puede ser menor al monto');
    }
    if ((_metodoPago == 'tarjeta_debito' ||
            _metodoPago == 'tarjeta_credito') &&
        _ultimos4Ctrl.text.length != 4)
      return setState(
          () => _error = 'Ingresa los últimos 4 dígitos de la tarjeta');

    setState(() { _isLoading = true; _error = null; });

    try {
      final body = <String, dynamic>{
        'sesion_caja_id': widget.sesionCajaId,
        'metodo_pago': _metodoPago,
        'monto': monto,
        'numero_pago': _numeroCtrl.text.trim(),
        if (_metodoPago == 'efectivo')
          'monto_recibido': double.tryParse(_montoRecibidoCtrl.text) ?? monto,
        if (_referenciaCtrl.text.trim().isNotEmpty)
          'referencia': _referenciaCtrl.text.trim(),
        if (_ultimos4Ctrl.text.length == 4)
          'ultimos_4_digitos': _ultimos4Ctrl.text,
      };

      await SalesService.registrarPago(widget.pedido.id, body);
      _close(success: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Error al registrar el pago'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: sw > 520 ? 480 : sw - 48),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Registrar pago',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827))),
                        Text(
                          'Pedido ${widget.pedido.numeroPedido} · '
                          'Total: ₡${widget.pedido.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoading ? null : _close,
                    icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFDC2626), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFFDC2626))),
                      ),
                    ],
                  ),
                ),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Método de pago
                      const Text('Método de pago',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Container(
                        height: 42,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: const Color(0xFFD1D5DB)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          key: const ValueKey('dd_metodo'),
                          value: _metodoPago,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: _metodos
                              .map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(_labelsMetodo[m] ?? m,
                                        style: const TextStyle(
                                            fontSize: 13)),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _metodoPago = v ?? 'efectivo'),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              label: 'Monto *',
                              ctrl: _montoCtrl,
                              hint: '0.00',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Field(
                              label: 'Número de pago *',
                              ctrl: _numeroCtrl,
                              hint: 'PAG-001',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Campos específicos por método
                      if (_metodoPago == 'efectivo') ...[
                        _Field(
                          label: 'Monto recibido *',
                          ctrl: _montoRecibidoCtrl,
                          hint: '0.00',
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                        ),
                        const SizedBox(height: 8),
                        // Cambio calculado en tiempo real
                        ValueListenableBuilder(
                          valueListenable: _montoRecibidoCtrl,
                          builder: (_, __, ___) => Container(
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
                                const Text('Cambio',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF15803D))),
                                Text(
                                  '₡${_cambio.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF16A34A)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else if (_metodoPago == 'tarjeta_debito' ||
                          _metodoPago == 'tarjeta_credito') ...[
                        Row(
                          children: [
                            Expanded(
                              child: _Field(
                                label: 'Últimos 4 dígitos *',
                                ctrl: _ultimos4Ctrl,
                                hint: '1234',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _Field(
                                label: 'Referencia',
                                ctrl: _referenciaCtrl,
                                hint: 'Ej: TXN-12345',
                              ),
                            ),
                          ],
                        ),
                      ] else if (_metodoPago == 'sinpe' ||
                          _metodoPago == 'transferencia') ...[
                        _Field(
                          label: 'Referencia / Número de confirmación',
                          ctrl: _referenciaCtrl,
                          hint: 'Ej: SINPE-12345',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _close,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _registrar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Registrar pago',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13, color: Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: Color(0xFF2563EB), width: 2)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}