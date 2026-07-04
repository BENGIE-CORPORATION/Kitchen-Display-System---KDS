import 'package:flutter/material.dart';
import '../../../../common/models/producto_models.dart';
import '../../../../common/services/api_service.dart';
import '../menu_provider.dart';
import 'menu_field.dart';

class ProductoSucursalModal extends StatefulWidget {
  final ProductoRead producto;
  final String sucursalId;
  final VoidCallback onSuccess;

  const ProductoSucursalModal({
    super.key,
    required this.producto,
    required this.sucursalId,
    required this.onSuccess,
  });

  @override
  State<ProductoSucursalModal> createState() => _ProductoSucursalModalState();
}

class _ProductoSucursalModalState extends State<ProductoSucursalModal> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  ProductoSucursalRead? _config;

  final _precioCtrl       = TextEditingController();
  final _precioCostoCtrl  = TextEditingController();
  final _stockCtrl        = TextEditingController(text: '0');
  final _stockMinCtrl     = TextEditingController(text: '0');
  final _ivaCtrl          = TextEditingController(text: '13.00');
  final _servicioCtrl     = TextEditingController(text: '10.00');

  bool _aplicaIva       = true;
  bool _aplicaServicio  = true;
  bool _disponibleVenta = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _precioCtrl.dispose();
    _precioCostoCtrl.dispose();
    _stockCtrl.dispose();
    _stockMinCtrl.dispose();
    _ivaCtrl.dispose();
    _servicioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final data = await ApiService.get(
          '/api/v1/productos/${widget.producto.id}/sucursales/${widget.sucursalId}');
      if (!mounted) return;
      final config = ProductoSucursalRead.fromJson(data);
      setState(() {
        _config = config;
        _precioCtrl.text = config.precioVenta.toStringAsFixed(2);
        _precioCostoCtrl.text = config.precioCosto?.toStringAsFixed(2) ?? '';
        _stockCtrl.text = config.stockDisponible.toStringAsFixed(3);
        _stockMinCtrl.text = config.stockMinimo.toStringAsFixed(3);
        _ivaCtrl.text = config.porcentajeIva.toStringAsFixed(2);
        _servicioCtrl.text = config.porcentajeServicio.toStringAsFixed(2);
        _aplicaIva = config.aplicaIva;
        _aplicaServicio = config.aplicaServicio;
        _disponibleVenta = config.disponibleVenta;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      // 404 = no configurado aún, mostrar formulario vacío
      if (e.statusCode == 404) {
        setState(() => _isLoading = false);
      } else {
        setState(() { _error = e.message; _isLoading = false; });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _close({bool success = false}) {
    if (!mounted) return;
    Navigator.of(context).pop();
    if (success) widget.onSuccess();
  }

  Future<void> _guardar() async {
    final precio = double.tryParse(_precioCtrl.text);
    if (precio == null || precio < 0)
      return setState(() => _error = 'El precio de venta es requerido');

    setState(() { _isSaving = true; _error = null; });

    final body = {
      'precio_venta': precio,
      'aplica_iva': _aplicaIva,
      'aplica_servicio': _aplicaServicio,
      'disponible_venta': _disponibleVenta,
      'porcentaje_iva': double.tryParse(_ivaCtrl.text) ?? 13.0,
      'porcentaje_servicio': double.tryParse(_servicioCtrl.text) ?? 10.0,
      'stock_disponible': double.tryParse(_stockCtrl.text) ?? 0,
      'stock_minimo': double.tryParse(_stockMinCtrl.text) ?? 0,
      if (_precioCostoCtrl.text.trim().isNotEmpty)
        'precio_costo': double.tryParse(_precioCostoCtrl.text) ?? 0,
    };

    try {
      if (_config != null) {
        // Actualizar configuración existente
        await MenuService.updateProductoSucursal(_config!.id, body);
      } else {
        // Crear nueva configuración
        await MenuService.createProductoSucursal(widget.producto.id, {
          ...body,
          'producto_id': widget.producto.id,
          'sucursal_id': widget.sucursalId,
        });
      }
      _close(success: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _isSaving = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al guardar la configuración';
        _isSaving = false;
      });
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
          maxWidth: sw > 560 ? 520 : sw - 48,
          maxHeight: sh * 0.90,
        ),
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
                        const Text('Configurar en sucursal',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827))),
                        Text(
                          widget.producto.nombre,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isSaving ? null : _close,
                    icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_error != null) ErrorBanner(message: _error!),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(
                        color: Color(0xFF2563EB)),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Estado en sucursal
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _config == null
                                ? const Color(0xFFFFFBEB)
                                : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _config == null
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFFBBF7D0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _config == null
                                    ? Icons.warning_amber_outlined
                                    : Icons.check_circle_outline,
                                size: 16,
                                color: _config == null
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _config == null
                                    ? 'No configurado en esta sucursal — se creará al guardar'
                                    : 'Ya configurado — se actualizarán los valores',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _config == null
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Precios
                        const Text('Precios',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151))),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: MenuField(
                                label: 'Precio de venta *',
                                ctrl: _precioCtrl,
                                hint: '0.00',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: MenuField(
                                label: 'Precio de costo',
                                ctrl: _precioCostoCtrl,
                                hint: '0.00',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Color(0xFFE5E7EB)),
                        const SizedBox(height: 16),

                        // Impuestos
                        const Text('Impuestos y cargos',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151))),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Switch(
                                        value: _aplicaIva,
                                        onChanged: (v) => setState(
                                            () => _aplicaIva = v),
                                        activeColor:
                                            const Color(0xFF2563EB),
                                      ),
                                      const Text('IVA',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF374151))),
                                    ],
                                  ),
                                  if (_aplicaIva)
                                    MenuField(
                                      label: 'Porcentaje IVA',
                                      ctrl: _ivaCtrl,
                                      hint: '13.00',
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Switch(
                                        value: _aplicaServicio,
                                        onChanged: (v) => setState(
                                            () => _aplicaServicio = v),
                                        activeColor:
                                            const Color(0xFF2563EB),
                                      ),
                                      const Text('Servicio',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF374151))),
                                    ],
                                  ),
                                  if (_aplicaServicio)
                                    MenuField(
                                      label: 'Porcentaje servicio',
                                      ctrl: _servicioCtrl,
                                      hint: '10.00',
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Color(0xFFE5E7EB)),
                        const SizedBox(height: 16),

                        // Stock
                        const Text('Stock',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151))),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: MenuField(
                                label: 'Stock disponible',
                                ctrl: _stockCtrl,
                                hint: '0',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: MenuField(
                                label: 'Stock mínimo',
                                ctrl: _stockMinCtrl,
                                hint: '0',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Switch(
                              value: _disponibleVenta,
                              onChanged: (v) =>
                                  setState(() => _disponibleVenta = v),
                              activeColor: const Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 8),
                            const Text('Disponible para venta',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF374151))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              ModalActions(
                isLoading: _isSaving,
                onCancel: _close,
                onSave: _guardar,
                saveLabel: _config != null ? 'Actualizar' : 'Configurar',
              ),
            ],
          ),
        ),
      ),
    );
  }
}