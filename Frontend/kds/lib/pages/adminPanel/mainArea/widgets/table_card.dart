import 'package:flutter/material.dart';
import '../../../../common/models/models.dart';
import '../../../../common/widgets/status_badge.dart';

/// Tarjeta individual de mesa. Muestra estado dinámico según [table.status].
class TableCard extends StatelessWidget {
  final TableModel table;
  final VoidCallback? onTap;

  const TableCard({super.key, required this.table, this.onTap});

  @override
  Widget build(BuildContext context) {
    final config = _TableConfig.from(table.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: config.borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mesa ${table.tableNumber}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827)),
                ),
                config.badge,
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (table.status) {
      case TableStatus.occupied:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                const Icon(Icons.people_outline,
                    size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text('${table.people ?? 0} personas',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '₡${(table.total ?? 0).toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827)),
            ),
          ],
        );
      case TableStatus.reserved:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              table.reservationName ?? '',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF111827)),
            ),
            const SizedBox(height: 4),
            Text(
              table.reservationTime ?? '',
              style:
                  const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ],
        );
      case TableStatus.available:
        return const Center(
          child: Text('Disponible',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
        );
    }
  }
}

class _TableConfig {
  final Color borderColor;
  final Widget badge;

  const _TableConfig({required this.borderColor, required this.badge});

  factory _TableConfig.from(TableStatus status) {
    switch (status) {
      case TableStatus.occupied:
        return _TableConfig(
          borderColor: const Color(0xFFFCA5A5),
          badge: StatusBadge.occupied(),
        );
      case TableStatus.reserved:
        return _TableConfig(
          borderColor: const Color(0xFFFDE68A),
          badge: StatusBadge.reserved(),
        );
      case TableStatus.available:
        return _TableConfig(
          borderColor: const Color(0xFFBBF7D0),
          badge: StatusBadge.available(),
        );
    }
  }
}