import 'package:flutter/material.dart';
import '../../../../common/services/api_service.dart';
import '../menu_provider.dart';
import 'menu_field.dart';

class AddCategoriaModal extends StatefulWidget {
  final String empresaId;
  final VoidCallback onSuccess;

  const AddCategoriaModal({
    super.key,
    required this.empresaId,
    required this.onSuccess,
  });

  @override
  State<AddCategoriaModal> createState() => _AddCategoriaModalState();
}

class _AddCategoriaModalState extends State<AddCategoriaModal> {
  bool _isLoading = false;
  String? _error;

  final _nombreCtrl      = TextEditingController();
  final _codigoCtrl      = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  String _tipo = 'alimento';

  static const _tipos = ['alimento', 'bebida', 'producto', 'servicio'];
  static const _labelsTipo = {
    'alimento': 'Alimento',
    'bebida': 'Bebida',
    'producto': 'Producto',
    'servicio': 'Servicio',
  };

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    _descripcionCtrl.dispose();
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
      await MenuService.createCategoria({
        'empresa_id': widget.empresaId,
        'nombre': _nombreCtrl.text.trim(),
        'tipo': _tipo,
        if (_codigoCtrl.text.trim().isNotEmpty)
          'codigo': _codigoCtrl.text.trim(),
        if (_descripcionCtrl.text.trim().isNotEmpty)
          'descripcion': _descripcionCtrl.text.trim(),
      });
      _close(success: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _isLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Error al crear la categoría'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Nueva Categoría',
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
                ErrorBanner(message: _error!),

              MenuField(
                  label: 'Nombre *',
                  ctrl: _nombreCtrl,
                  hint: 'Ej: Entradas'),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: MenuField(
                        label: 'Código',
                        ctrl: _codigoCtrl,
                        hint: 'Ej: ENT'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        menuLabel('Tipo *'),
                        const SizedBox(height: 6),
                        menuDropdown(
                          child: DropdownButton<String>(
                            key: const ValueKey('dd_tipo_cat'),
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
                                setState(() => _tipo = v ?? 'alimento'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              MenuField(
                label: 'Descripción',
                ctrl: _descripcionCtrl,
                hint: 'Opcional',
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              ModalActions(
                isLoading: _isLoading,
                onCancel: _close,
                onSave: _guardar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}