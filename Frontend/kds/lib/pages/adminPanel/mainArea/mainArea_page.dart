import 'package:flutter/material.dart';
import '../../../common/models/models.dart';
import './widgets/table_card.dart';

/// Pantalla de Salón Principal.
/// [tables] viene del backend; la cantidad de tarjetas es dinámica.
class MainAreaPage extends StatelessWidget {
  final List<TableModel> tables;
  final ValueChanged<TableModel>? onTableTap;

  const MainAreaPage({
    super.key,
    required this.tables,
    this.onTableTap,
  });

  @override
  Widget build(BuildContext context) {
    final occupied = tables.where((t) => t.status == TableStatus.occupied).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Salón Principal',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827))),
                    Text('$occupied mesas ocupadas',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280))),
                  ],
                ),
                Row(
                  children: [
                    _HeaderBtn(
                        icon: Icons.history, label: 'Historial', onTap: () {}),
                    const SizedBox(width: 12),
                    _HeaderBtn(
                        icon: Icons.grid_3x3,
                        label: 'Selector',
                        onTap: () {}),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Grid dinámico de mesas
            LayoutBuilder(
              builder: (context, constraints) {
                final crossCount = constraints.maxWidth > 900
                    ? 4
                    : constraints.maxWidth > 600
                        ? 3
                        : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: tables.length,
                  itemBuilder: (_, i) => TableCard(
                    table: tables[i],
                    onTap: () => onTableTap?.call(tables[i]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeaderBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF374151)),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151))),
          ],
        ),
      ),
    );
  }
}