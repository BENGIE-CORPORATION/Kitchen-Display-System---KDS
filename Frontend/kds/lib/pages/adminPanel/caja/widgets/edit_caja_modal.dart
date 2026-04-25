import 'package:flutter/material.dart';
import '../../../../common/models/caja_models.dart';
import '../../../../common/services/api_service.dart';
import '../caja_provider.dart';
import 'caja_field.dart';

class EditCajaModal extends StatefulWidget {
  final CajaRead caja;
  final VoidCallback onSuccess;

  const EditCajaModal({
    super.key,
    required this.caja,
    required this.onSuccess,
  });

  @override
  State<EditCajaModal> createState() => _EditCajaModalState();
}

class _EditCajaModalState extends State<EditCajaModal> {
  bool _isLoading = false;
  String? _error;

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _serieCtrl;
  late String _tipo;
  late String _estado;

  static const _tipos = ['principal', 'secundaria', 'express'];
  static const _estados = ['activo', 'inactivo', 'mantenimiento'];
  static const _labelsTipo = {
    'principal': 'Principal',
    'secundaria': 'Secundaria',
    'express': 'Express',
  };
  static const _labelsEstado = {
    'activo': 'Activo',
    'inactivo': 'Inactivo',
    'mantenimiento': 'En mantenimiento',
  };

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.caja.nombre);
    _descripcionCtrl =
        TextEditingController(text: widget.caja.descripcion ?? '');
    _serieCtrl =
        TextEditingController(text: widget.caja.numeroSerieFiscal ?? '');
    _tipo = widget.caja.tipo;
    _estado = widget.caja.estado;
  }

  @override
  void dispose() {
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
    if (_nombreCtrl.text.trim().isEmpty)
      return setState(() => _error = 'El nombre es requerido');

    setState(() { _isLoading = true; _error = null; });

    try {
      await CajaService.updateCaja(widget.caja.id, {
        'nombre': _nombreCtrl.text.trim(),
        'tipo': _tipo,
        'estado': _estado,
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
      setState(() {
        _error = 'Error al actualizar la caja';
        _isLoading = false;
      });
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Editar Caja',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827))),
                        Text(widget.caja.codigo,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280))),
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

              CajaField(label: 'Nombre *', ctrl: _nombreCtrl,
                  hint: 'Ej: Caja Principal'),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Tipo'),
                        const SizedBox(height: 6),
                        _dropdown(
                          child: DropdownButton<String>(
                            key: const ValueKey('dd_tipo_edit'),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Estado'),
                        const SizedBox(height: 6),
                        _dropdown(
                          child: DropdownButton<String>(
                            key: const ValueKey('dd_estado_edit'),
                            value: _estado,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            items: _estados
                                .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(_labelsEstado[e] ?? e,
                                          style: const TextStyle(
                                              fontSize: 13)),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _estado = v ?? 'activo'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                          : const Text('Guardar cambios',
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