import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../employees_provider.dart';
import 'employee_field.dart';

class AddEmployeeModal extends StatefulWidget {
  const AddEmployeeModal({super.key});

  @override
  State<AddEmployeeModal> createState() => _AddEmployeeModalState();
}

class _AddEmployeeModalState extends State<AddEmployeeModal> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();

  String _rol = 'empleado';
  bool _isLoading = false;
  String? _error;
  bool _showPassword = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
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
    final ok = await provider.crearEmpleado(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      nombreCompleto: _nombreCtrl.text.trim(),
      rolGlobal: _rol,
      telefono: _telefonoCtrl.text.trim().isEmpty
          ? null
          : _telefonoCtrl.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _error = provider.error ?? 'Error al crear el empleado';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.person_add_outlined,
                        color: Color(0xFF6366F1), size: 20),
                    const SizedBox(width: 8),
                    const Text('Nuevo Empleado',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
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
                  EmployeeErrorBanner(message: _error!),
                  const SizedBox(height: 16),
                ],

                EmployeeField(
                  label: 'Nombre completo *',
                  ctrl: _nombreCtrl,
                  hint: 'Ej: Juan Perez',
                  validator: (v) =>
                      (v == null || v.trim().length < 2)
                          ? 'Minimo 2 caracteres'
                          : null,
                ),
                const SizedBox(height: 14),

                EmployeeField(
                  label: 'Email *',
                  ctrl: _emailCtrl,
                  hint: 'correo@empresa.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido';
                    if (!v.contains('@')) return 'Email invalido';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Password con toggle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Contrasena *',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: !_showPassword,
                      validator: (v) =>
                          (v == null || v.length < 8)
                              ? 'Minimo 8 caracteres'
                              : null,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Min. 8 caracteres',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Color(0xFF9CA3AF)),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: const Color(0xFF9CA3AF),
                          ),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFFD1D5DB))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFFD1D5DB))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFF6366F1), width: 1.5)),
                        errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFFEF4444))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                EmployeeField(
                  label: 'Telefono (opcional)',
                  ctrl: _telefonoCtrl,
                  hint: '+506 8888-8888',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),

                RolDropdown(
                  value: _rol,
                  onChanged: (v) => setState(() => _rol = v ?? 'empleado'),
                ),
                const SizedBox(height: 24),

                EmployeeModalActions(
                  isLoading: _isLoading,
                  onCancel: () => Navigator.of(context).pop(),
                  onSave: _submit,
                  saveLabel: 'Crear Empleado',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}