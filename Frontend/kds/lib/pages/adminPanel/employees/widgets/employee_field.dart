import 'package:flutter/material.dart';

// ─── Campo de formulario ──────────────────────────────────────────────────────

class EmployeeField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? hint;
  final bool obscure;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool enabled;

  const EmployeeField({
    super.key,
    required this.label,
    required this.ctrl,
    this.hint,
    this.obscure = false,
    this.validator,
    this.keyboardType,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          validator: validator,
          keyboardType: keyboardType,
          enabled: enabled,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            filled: true,
            fillColor:
                enabled ? Colors.white : const Color(0xFFF9FAFB),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFF6366F1), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Dropdown de rol ──────────────────────────────────────────────────────────

class RolDropdown extends StatelessWidget {
  final String value;
  final void Function(String?) onChanged;
  final List<String> opciones;

  const RolDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.opciones = const ['admin_empresa', 'empleado'],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Rol *',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
          ),
          items: opciones
              .map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(_labelRol(r),
                        style: const TextStyle(fontSize: 14)),
                  ))
              .toList(),
        ),
      ],
    );
  }

  String _labelRol(String rol) => switch (rol) {
        'super_admin' => 'Super Admin',
        'admin_empresa' => 'Administrador',
        'empleado' => 'Empleado',
        _ => rol,
      };
}

// ─── Badge de rol ─────────────────────────────────────────────────────────────

class RolBadge extends StatelessWidget {
  final String rol;

  const RolBadge({super.key, required this.rol});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (rol) {
      'super_admin' => ('Super Admin', const Color(0xFFF5F3FF), const Color(0xFF7C3AED)),
      'admin_empresa' => ('Admin', const Color(0xFFEFF6FF), const Color(0xFF1D4ED8)),
      'empleado' => ('Empleado', const Color(0xFFF0FDF4), const Color(0xFF15803D)),
      _ => (rol, const Color(0xFFF3F4F6), const Color(0xFF6B7280)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

// ─── Badge de estado ──────────────────────────────────────────────────────────

class EstadoBadge extends StatelessWidget {
  final String estado;

  const EstadoBadge({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg, dot) = switch (estado) {
      'activo' => ('Activo', const Color(0xFFF0FDF4), const Color(0xFF15803D), const Color(0xFF22C55E)),
      'inactivo' => ('Inactivo', const Color(0xFFF9FAFB), const Color(0xFF6B7280), const Color(0xFF9CA3AF)),
      'suspendido' => ('Suspendido', const Color(0xFFFFF7ED), const Color(0xFFC2410C), const Color(0xFFF97316)),
      _ => (estado, const Color(0xFFF3F4F6), const Color(0xFF6B7280), const Color(0xFF9CA3AF)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

// ─── Banner de error ──────────────────────────────────────────────────────────

class EmployeeErrorBanner extends StatelessWidget {
  final String message;

  const EmployeeErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: Color(0xFFEF4444), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: Color(0xFFDC2626), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─── Acciones de modal ────────────────────────────────────────────────────────

class EmployeeModalActions extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final String saveLabel;
  final Color? saveColor;

  const EmployeeModalActions({
    super.key,
    required this.isLoading,
    required this.onCancel,
    required this.onSave,
    this.saveLabel = 'Guardar',
    this.saveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: isLoading ? null : onCancel,
          child: const Text('Cancelar',
              style: TextStyle(color: Color(0xFF6B7280))),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: isLoading ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: saveColor ?? const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(saveLabel,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}