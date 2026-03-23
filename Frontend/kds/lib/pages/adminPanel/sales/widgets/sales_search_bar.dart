import 'package:flutter/material.dart';
import '../../../../common/models/models.dart';

// ── SalesSearchBar ────────────────────────────────────────────────────────────
class SalesSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final List<Product> filteredProducts;
  final ValueChanged<Product> onProductSelected;

  const SalesSearchBar({
    super.key,
    required this.controller,
    required this.filteredProducts,
    required this.onProductSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Buscar producto por nombre o código...',
              hintStyle:
                  const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              prefixIcon:
                  const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFF3B82F6), width: 2)),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          if (filteredProducts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filteredProducts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = filteredProducts[i];
                  return InkWell(
                    onTap: () => onProductSelected(p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Text(p.clave,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: Color(0xFF6B7280))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(p.nombre,
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF111827))),
                          ),
                          Text(
                            '₡${p.precio.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

