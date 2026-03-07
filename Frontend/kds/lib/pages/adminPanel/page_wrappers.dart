// ─────────────────────────────────────────────────────────────────────────────
// Wrappers de páginas para el router.
// Cada wrapper:
//   1. Registra su ChangeNotifierProvider
//   2. Llama a load() en initState
//   3. Maneja loading / error / data con Consumer
//
// El router solo importa este archivo.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'inventory/inventory_page.dart';
import 'inventory/inventory_provider.dart';
import 'mainArea/mainArea_page.dart';
import 'mainArea/mainArea_provider.dart';
import 'suppliers/suppliers_page.dart';
import 'suppliers/suppliers_provider.dart';
import 'sales/sales_page.dart';
import 'sales/sales_provider.dart';

// ── Inventory ─────────────────────────────────────────────────────────────────
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => InventoryProvider()..load(),
      child: Consumer<InventoryProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const _LoadingView();
          if (provider.error != null) return _ErrorView(provider.error!);

          return InventoryPage(
            items: provider.items,
            onAdjust: (item) => provider.adjust(item.id, item.currentStock),
          );
        },
      ),
    );
  }
}

// ── MainArea ──────────────────────────────────────────────────────────────────
class MainAreaScreen extends StatelessWidget {
  const MainAreaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MainAreaProvider()..load(),
      child: Consumer<MainAreaProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const _LoadingView();
          if (provider.error != null) return _ErrorView(provider.error!);

          return MainAreaPage(
            tables: provider.tables,
            onTableTap: (table) {
              // TODO: navegar a detalle de mesa
            },
          );
        },
      ),
    );
  }
}

// ── Providers (Suppliers) ─────────────────────────────────────────────────────
class ProvidersScreen extends StatelessWidget {
  const ProvidersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SuppliersProvider()..load(),
      child: Consumer<SuppliersProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const _LoadingView();
          if (provider.error != null) return _ErrorView(provider.error!);

          return ProvidersPage(
            suppliers: provider.suppliers,
            onViewSupplier: (supplier) {
              // TODO: navegar a detalle de proveedor
            },
            onCreateOrder: () {
              // TODO: navegar a nueva orden
            },
          );
        },
      ),
    );
  }
}

// ── Sales ─────────────────────────────────────────────────────────────────────
class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SalesProvider()..loadProducts(),
      child: Consumer<SalesProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const _LoadingView();
          if (provider.error != null) return _ErrorView(provider.error!);

          return SalesPage(
            products: provider.products,
            initialItems: provider.currentItems,
          );
        },
      ),
    );
  }
}

// ── Shared UI ─────────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF9FAFB),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView(this.message);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 40),
            const SizedBox(height: 12),
            Text(
              'Error al cargar datos',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827)),
            ),
            const SizedBox(height: 4),
            Text(message,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {}, // TODO: retry
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}