import 'package:flutter/material.dart';

// ─── Campo de texto ───────────────────────────────────────────────────────────

class ConfigField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? hint;
  final bool enabled;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;

  const ConfigField({
    super.key,
    required this.label,
    required this.ctrl,
    this.hint,
    this.enabled = true,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
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
          enabled: enabled,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            filled: true,
            fillColor: enabled
                ? Colors.white
                : const Color(0xFFF9FAFB),
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
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Dropdown generico ────────────────────────────────────────────────────────

class ConfigDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<MapEntry<String, String>> opciones; // value → label
  final void Function(String?) onChanged;
  final String? Function(String?)? validator;

  const ConfigDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.opciones,
    required this.onChanged,
    this.validator,
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
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          validator: validator,
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFF6366F1), width: 1.5),
            ),
          ),
          items: opciones
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value,
                        style: const TextStyle(fontSize: 14)),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ─── Banner de error ──────────────────────────────────────────────────────────

class ConfigErrorBanner extends StatelessWidget {
  final String message;

  const ConfigErrorBanner({super.key, required this.message});

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

// ─── Banner de exito ──────────────────────────────────────────────────────────

class ConfigSuccessBanner extends StatelessWidget {
  final String message;

  const ConfigSuccessBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              color: Color(0xFF16A34A), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: Color(0xFF15803D), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─── Acciones de modal ────────────────────────────────────────────────────────

class ConfigModalActions extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final String saveLabel;

  const ConfigModalActions({
    super.key,
    required this.isLoading,
    required this.onCancel,
    required this.onSave,
    this.saveLabel = 'Guardar',
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
            backgroundColor: const Color(0xFF6366F1),
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

// ─── Etiqueta de seccion ──────────────────────────────────────────────────────

class ConfigSectionLabel extends StatelessWidget {
  final String label;

  const ConfigSectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151))),
    );
  }
}

// ─── Badge de estado sucursal ─────────────────────────────────────────────────

class SucursalEstadoBadge extends StatelessWidget {
  final String estado;

  const SucursalEstadoBadge({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg, dot) = switch (estado) {
      'activo' => (
          'Activo',
          const Color(0xFFF0FDF4),
          const Color(0xFF15803D),
          const Color(0xFF22C55E)
        ),
      'mantenimiento' => (
          'Mantenimiento',
          const Color(0xFFFFFBEB),
          const Color(0xFF92400E),
          const Color(0xFFF59E0B)
        ),
      _ => (
          'Inactivo',
          const Color(0xFFF9FAFB),
          const Color(0xFF6B7280),
          const Color(0xFF9CA3AF)
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg)),
        ],
      ),
    );
  }
}