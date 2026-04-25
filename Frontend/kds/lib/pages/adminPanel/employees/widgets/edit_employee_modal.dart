import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../employees_provider.dart';
import 'employee_field.dart';

class EditEmployeeModal extends StatefulWidget {
  final PerfilPublicRead perfil;

  const EditEmployeeModal({super.key, required this.perfil});

  @override
  State<EditEmployeeModal> createState() => _EditEmployeeModalState();
}

class _EditEmployeeModalState extends State<EditEmployeeModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _telefonoCtrl;

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.perfil.nombreCompleto);
    _telefonoCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final provider = context.read<EmployeesProvider>();
    final ok = await provider.actualizarPerfil(
      userId: widget.perfil.id,
      nombreCompleto: _nombreCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim().isEmpty
          ? null
          : _telefonoCtrl.text.trim(),
    );

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
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit_outlined,
                        color: Color(0xFF6366F1), size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Editar Perfil',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(widget.perfil.email,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF6B7280))),
                const SizedBox(height: 20),

                if (_error != null) ...[
                  EmployeeErrorBanner(message: _error!),
                  const SizedBox(height: 16),
                ],

                EmployeeField(
                  label: 'Nombre completo *',
                  ctrl: _nombreCtrl,
                  validator: (v) =>
                      (v == null || v.trim().length < 2)
                          ? 'Minimo 2 caracteres'
                          : null,
                ),
                const SizedBox(height: 14),

                EmployeeField(
                  label: 'Telefono (opcional)',
                  ctrl: _telefonoCtrl,
                  hint: '+506 8888-8888',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),

                // Email — solo lectura
                EmployeeField(
                  label: 'Email',
                  ctrl: TextEditingController(text: widget.perfil.email),
                  enabled: false,
                ),
                const SizedBox(height: 24),

                EmployeeModalActions(
                  isLoading: _isLoading,
                  onCancel: () => Navigator.of(context).pop(),
                  onSave: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}