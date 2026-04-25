import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config_provider.dart';
import 'config_field.dart';

class AddSucursalModal extends StatefulWidget {
  const AddSucursalModal({super.key});

  @override
  State<AddSucursalModal> createState() => _AddSucursalModalState();
}

class _AddSucursalModalState extends State<AddSucursalModal> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _ciudadCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  String _tipo = 'sucursal';
  String _estado = 'activo';
  bool _isLoading = false;
  String? _error;

  static const _tipos = [
    MapEntry('principal', 'Principal'),
    MapEntry('sucursal', 'Sucursal'),
    MapEntry('bodega', 'Bodega'),
    MapEntry('punto_venta', 'Punto de Venta'),
  ];

  static const _estados = [
    MapEntry('activo', 'Activo'),
    MapEntry('mantenimiento', 'Mantenimiento'),
  ];

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _nombreCtrl.dispose();
    _direccionCtrl.dispose();
    _ciudadCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final provider = context.read<ConfigProvider>();
    final empresaId = provider.empresa?.id ?? '';

    final body = <String, dynamic>{
      'empresa_id': empresaId,
      'codigo': _codigoCtrl.text.trim().toUpperCase(),
      'nombre': _nombreCtrl.text.trim(),
      'tipo': _tipo,
      'estado': _estado,
      if (_direccionCtrl.text.trim().isNotEmpty)
        'direccion': _direccionCtrl.text.trim(),
      if (_ciudadCtrl.text.trim().isNotEmpty)
        'ciudad': _ciudadCtrl.text.trim(),
      if (_telefonoCtrl.text.trim().isNotEmpty)
        'telefono': _telefonoCtrl.text.trim(),
      if (_emailCtrl.text.trim().isNotEmpty)
        'email': _emailCtrl.text.trim(),
    };

    final ok = await provider.createSucursal(body);

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _error = provider.error ?? 'Error al crear la sucursal';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.store_outlined,
                          color: Color(0xFF6366F1), size: 20),
                      const SizedBox(width: 8),
                      const Text('Nueva Sucursal',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_error != null) ...[
                    ConfigErrorBanner(message: _error!),
                    const SizedBox(height: 16),
                  ],

                  // Codigo y nombre
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: ConfigField(
                          label: 'Codigo *',
                          ctrl: _codigoCtrl,
                          hint: 'SUC-001',
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Requerido'
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ConfigField(
                          label: 'Nombre *',
                          ctrl: _nombreCtrl,
                          hint: 'Sucursal Norte',
                          validator: (v) =>
                              (v == null || v.trim().length < 2)
                                  ? 'Minimo 2 caracteres'
                                  : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Tipo y estado
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ConfigDropdown(
                          label: 'Tipo *',
                          value: _tipo,
                          opciones: _tipos,
                          onChanged: (v) =>
                              setState(() => _tipo = v ?? 'sucursal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ConfigDropdown(
                          label: 'Estado *',
                          value: _estado,
                          opciones: _estados,
                          onChanged: (v) =>
                              setState(() => _estado = v ?? 'activo'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  ConfigField(
                    label: 'Direccion',
                    ctrl: _direccionCtrl,
                    hint: 'Av. Principal 123',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ConfigField(
                          label: 'Ciudad',
                          ctrl: _ciudadCtrl,
                          hint: 'Quito',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ConfigField(
                          label: 'Telefono',
                          ctrl: _telefonoCtrl,
                          hint: '+593 2 000 0000',
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  ConfigField(
                    label: 'Email',
                    ctrl: _emailCtrl,
                    hint: 'sucursal@empresa.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),

                  ConfigModalActions(
                    isLoading: _isLoading,
                    onCancel: () => Navigator.of(context).pop(),
                    onSave: _submit,
                    saveLabel: 'Crear Sucursal',
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