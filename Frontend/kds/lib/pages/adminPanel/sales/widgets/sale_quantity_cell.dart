import 'package:flutter/material.dart';

/// Widget de control de cantidad para una fila de venta.
class SaleQuantityCell extends StatelessWidget {
  final int cantidad;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const SaleQuantityCell({
    super.key,
    required this.cantidad,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _QtyButton(icon: Icons.remove, onTap: onDecrement),
        SizedBox(
          width: 36,
          child: Text(
            '$cantidad',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _QtyButton(icon: Icons.add, onTap: onIncrement),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: const Color(0xFF374151)),
      ),
    );
  }
}