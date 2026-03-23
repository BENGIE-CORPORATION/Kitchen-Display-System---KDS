import 'package:flutter/material.dart';

/// Footer de la pantalla de ventas: campo de cliente + total + botón cobrar.
class SaleFooter extends StatefulWidget {
  final String cliente;
  final double total;
  final bool hasItems;
  final ValueChanged<String> onClienteChanged;
  final VoidCallback onCancelar;
  final VoidCallback? onCobrar;

  const SaleFooter({
    super.key,
    required this.cliente,
    required this.total,
    required this.hasItems,
    required this.onClienteChanged,
    required this.onCancelar,
    this.onCobrar,
  });

  @override
  State<SaleFooter> createState() => _SaleFooterState();
}

class _SaleFooterState extends State<SaleFooter> {
  late TextEditingController _clienteController;

  @override
  void initState() {
    super.initState();
    _clienteController = TextEditingController(text: widget.cliente);
    _clienteController.selection = TextSelection.fromPosition(
      TextPosition(offset: _clienteController.text.length),
    );
  }

  @override
  void didUpdateWidget(covariant SaleFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Solo actualiza si el cambio vino de afuera (ej: cancelar venta),
    // no mientras el usuario está escribiendo
    if (widget.cliente != _clienteController.text) {
      _clienteController.text = widget.cliente;
      _clienteController.selection = TextSelection.fromPosition(
        TextPosition(offset: _clienteController.text.length),
      );
    }
  }

  @override
  void dispose() {
    _clienteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Panel Cliente ──────────────────────────────────────────────────
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cliente:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _clienteController,
                  onChanged: widget.onClienteChanged,
                  decoration: InputDecoration(
                    hintText: 'Nombre del cliente (opcional)',
                    hintStyle: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 13,
                    ),
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
                      borderSide: const BorderSide(
                          color: Color(0xFF3B82F6), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _FooterBtn(label: 'Pendiente', onTap: () {}),
                    const SizedBox(width: 8),
                    _FooterBtn(label: 'Abiertos', onTap: () {}),
                    const SizedBox(width: 8),
                    _FooterBtn(
                      label: 'Cancelar',
                      onTap: widget.onCancelar,
                      bgColor: const Color(0xFFFEF2F2),
                      textColor: const Color(0xFFDC2626),
                      icon: Icons.close,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),

        // ── Panel Total + Cobrar ───────────────────────────────────────────
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total a Cobrar:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                    Text(
                      '₡${widget.total.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onCobrar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.onCobrar != null
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFD1D5DB),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'COBRAR',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Botón auxiliar del panel cliente ─────────────────────────────────────────
class _FooterBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color bgColor;
  final Color textColor;
  final IconData? icon;

  const _FooterBtn({
    required this.label,
    required this.onTap,
    this.bgColor = const Color(0xFFF3F4F6),
    this.textColor = const Color(0xFF374151),
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: textColor),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}