import 'package:flutter/material.dart';

/// Columna genérica para AppDataTable
class AppTableColumn {
  final String label;
  final String key;
  final TextAlign align;
  final double? flex;
  final Widget Function(dynamic value, dynamic row)? cellBuilder;

  const AppTableColumn({
    required this.label,
    required this.key,
    this.align = TextAlign.left,
    this.flex,
    this.cellBuilder,
  });
}

/// Tabla reutilizable para todas las vistas del admin.
/// Recibe columnas y rows dinámicos desde el backend.
class AppDataTable extends StatelessWidget {
  final List<AppTableColumn> columns;
  final List<Map<String, dynamic>> rows;
  final String emptyMessage;
  final Color headerColor;

  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyMessage = 'No hay datos disponibles',
    this.headerColor = const Color(0xFF2563EB), // blue-600
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            _buildHeader(),
            if (rows.isEmpty) _buildEmpty() else _buildRows(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: headerColor,
      child: Row(
        children: columns.map((col) {
          return Expanded(
            flex: (col.flex ?? 1).toInt(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                col.label.toUpperCase(),
                textAlign: col.align,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildRows() {
    return Column(
      children: rows.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;
        return Container(
          decoration: BoxDecoration(
            color: index % 2 == 0 ? Colors.white : const Color(0xFFF9FAFB),
            border: const Border(
              bottom: BorderSide(color: Color(0xFFF3F4F6)),
            ),
          ),
          child: Row(
            children: columns.map((col) {
              final value = row[col.key];
              return Expanded(
                flex: (col.flex ?? 1).toInt(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: col.cellBuilder != null
                      ? col.cellBuilder!(value, row)
                      : Text(
                          value?.toString() ?? '-',
                          textAlign: col.align,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF111827),
                          ),
                        ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
