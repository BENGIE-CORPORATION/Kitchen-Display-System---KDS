import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config_provider.dart';
import 'config_field.dart';

class EditSucursalModal extends StatefulWidget {
  final SucursalRead sucursal;

  const EditSucursalModal({super.key, required this.sucursal});

  @override
  State<EditSucursalModal> createState() => _EditSucursalModalState();
}

class _EditSucursalModalState extends State<EditSucursalModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _ciudadCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _emailCtrl;

  late String _tipo;
  late String _estado;
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
    MapEntry('inactivo', 'Inactivo'),
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.sucursal;
    _nombreCtrl = TextEditingController(text: s.nombre);
    _direccionCtrl = TextEditingController(text: s.direccion ?? '');
    _ciudadCtrl = TextEditingController(text: s.ciudad ?? '');
    _telefonoCtrl = TextEditingController(text: s.telefono ?? '');
    _emailCtrl = TextEditingController(text: s.email ?? '');
    _tipo = s.tipo;
    _estado = s.estado;
  }

  @override
  void dispose() {
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

    final s = widget.sucursal;
    final body = <String, dynamic>{};

    if (_nombreCtrl.text.trim() != s.nombre)
      body['nombre'] = _nombreCtrl.text.trim();
    if (_tipo != s.tipo) body['tipo'] = _tipo;
    if (_estado != s.estado) body['estado'] = _estado;
    if (_direccionCtrl.text.trim() != (s.direccion ?? ''))
      body['direccion'] = _direccionCtrl.text.trim().isEmpty
          ? null
          : _direccionCtrl.text.trim();
    if (_ciudadCtrl.text.trim() != (s.ciudad ?? ''))
      body['ciudad'] = _ciudadCtrl.text.trim().isEmpty
          ? null
          : _ciudadCtrl.text.trim();
    if (_telefonoCtrl.text.trim() != (s.telefono ?? ''))
      body['telefono'] = _telefonoCtrl.text.trim().isEmpty
          ? null
          : _telefonoCtrl.text.trim();
    if (_emailCtrl.text.trim() != (s.email ?? ''))
      body['email'] = _emailCtrl.text.trim().isEmpty
          ? null
          : _emailCtrl.text.trim();

    if (body.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final provider = context.read<ConfigProvider>();
    final ok = await provider.updateSucursal(s.id, body);

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _error = provider.error ?? 'Error al actualizar';
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
                      const Icon(Icons.edit_outlined,
                          color: Color(0xFF6366F1), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Editar Sucursal',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            Text(widget.sucursal.codigo,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280))),
                          ],
                        ),
                      ),
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

                  ConfigField(
                    label: 'Nombre *',
                    ctrl: _nombreCtrl,
                    validator: (v) =>
                        (v == null || v.trim().length < 2)
                            ? 'Minimo 2 caracteres'
                            : null,
                  ),
                  const SizedBox(height: 14),

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
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ConfigField(
                          label: 'Telefono',
                          ctrl: _telefonoCtrl,
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  ConfigField(
                    label: 'Email',
                    ctrl: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),

                  ConfigModalActions(
                    isLoading: _isLoading,
                    onCancel: () => Navigator.of(context).pop(),
                    onSave: _submit,
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