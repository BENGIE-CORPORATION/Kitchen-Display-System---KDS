import 'package:flutter/material.dart';
import '../../../../common/services/api_service.dart';
import '../caja_provider.dart';
import 'caja_field.dart';

class AddCajaModal extends StatefulWidget {
  final String sucursalId;
  final VoidCallback onSuccess;

  const AddCajaModal({
    super.key,
    required this.sucursalId,
    required this.onSuccess,
  });

  @override
  State<AddCajaModal> createState() => _AddCajaModalState();
}

class _AddCajaModalState extends State<AddCajaModal> {
  bool _isLoading = false;
  String? _error;

  final _codigoCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _serieCtrl = TextEditingController();
  String _tipo = 'principal';

  static const _tipos = ['principal', 'secundaria', 'express'];
  static const _labelsTipo = {
    'principal': 'Principal',
    'secundaria': 'Secundaria',
    'express': 'Express',
  };

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _serieCtrl.dispose();
    super.dispose();
  }

  void _close({bool success = false}) {
    if (!mounted) return;
    Navigator.of(context).pop();
    if (success) widget.onSuccess();
  }

  Future<void> _guardar() async {
    if (_codigoCtrl.text.trim().isEmpty)
      return setState(() => _error = 'El código es requerido');
    if (_nombreCtrl.text.trim().isEmpty)
      return setState(() => _error = 'El nombre es requerido');

    setState(() { _isLoading = true; _error = null; });

    try {
      await CajaService.createCaja({
        'sucursal_id': widget.sucursalId,
        'codigo': _codigoCtrl.text.trim(),
        'nombre': _nombreCtrl.text.trim(),
        'tipo': _tipo,
        if (_descripcionCtrl.text.trim().isNotEmpty)
          'descripcion': _descripcionCtrl.text.trim(),
        if (_serieCtrl.text.trim().isNotEmpty)
          'numero_serie_fiscal': _serieCtrl.text.trim(),
      });
      _close(success: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Error al crear la caja'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Nueva Caja',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827))),
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

              Row(
                children: [
                  Expanded(
                    child: CajaField(
                      label: 'Código *',
                      ctrl: _codigoCtrl,
                      hint: 'Ej: CAJA-01',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Tipo'),
                        const SizedBox(height: 6),
                        _dropdown(
                          child: DropdownButton<String>(
                            key: const ValueKey('dd_tipo_caja'),
                            value: _tipo,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            items: _tipos
                                .map((t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(_labelsTipo[t] ?? t,
                                          style: const TextStyle(
                                              fontSize: 13)),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _tipo = v ?? 'principal'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CajaField(
                  label: 'Nombre *',
                  ctrl: _nombreCtrl,
                  hint: 'Ej: Caja Principal'),
              const SizedBox(height: 12),
              CajaField(
                  label: 'Descripción',
                  ctrl: _descripcionCtrl,
                  hint: 'Opcional',
                  maxLines: 2),
              const SizedBox(height: 12),
              CajaField(
                  label: 'Número de serie fiscal',
                  ctrl: _serieCtrl,
                  hint: 'Opcional'),
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
                      onPressed: _isLoading ? null : _guardar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Guardar',
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

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF374151)));

  Widget _dropdown({required Widget child}) => Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      );
}