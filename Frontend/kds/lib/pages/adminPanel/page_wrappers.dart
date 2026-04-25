import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/providers/auth_provider.dart';
import 'inventory/inventory_page.dart';
import 'inventory/inventory_provider.dart';
import 'mainArea/mainArea_page.dart';
import 'mainArea/mainArea_provider.dart';
import 'suppliers/suppliers_page.dart';
import 'suppliers/suppliers_provider.dart';
import 'sales/sales_page.dart';
import 'sales/sales_provider.dart';
import 'ordenes_compra/ordenes_compra_page.dart';
import 'ordenes_compra/ordenes_compra_provider.dart';
import 'employees/employees_page.dart';
import 'employees/employees_provider.dart';
import 'config/config_page.dart';
import 'config/config_provider.dart';


// ── Inventory ─────────────────────────────────────────────────────────────────
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sucursalId = context.read<AuthProvider>().sucursalId;

    if (sucursalId == null) return const _SinSucursalView();

    return ChangeNotifierProvider(
      create: (_) => InventoryProvider()..load(sucursalId),
      child: Consumer<InventoryProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const _LoadingView();
          if (provider.error != null) {
            return _ErrorView(
              provider.error!,
              onRetry: () => provider.load(sucursalId, refresh: true),
            );
          }
          return InventoryPage(
            provider: provider,
            sucursalId: sucursalId,
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
          if (provider.error != null) {
            return _ErrorView(provider.error!, onRetry: provider.load);
          }
          return MainAreaPage(
            tables: provider.tables,
            onTableTap: (table) {},
          );
        },
      ),
    );
  }
}

// ── Suppliers ─────────────────────────────────────────────────────────────────
class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    return ChangeNotifierProvider(
      // init() inyecta el AuthProvider antes de load() para que
      // SuppliersService pueda resolver empresa_id correctamente.
      create: (_) => SuppliersProvider()
        ..init(auth)
        ..load(),
      child: Consumer<SuppliersProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const _LoadingView();
          if (provider.error != null) {
            return _ErrorView(
              provider.error!,
              onRetry: provider.reload,
            );
          }
          return SuppliersPage(provider: provider);
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
    final auth = context.read<AuthProvider>();

    return ChangeNotifierProvider(
      create: (_) => SalesProvider()
        ..init(auth)
        ..load(),
      child: Consumer<SalesProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const _LoadingView();
          if (provider.error != null) {
            return _ErrorView(
              provider.error!,
              onRetry: provider.reload,
            );
          }
          return SalesPage(provider: provider);
        },
      ),
    );
  }
}

// ── Órdenes de Compra ─────────────────────────────────────────────────────────
class OrdenesCompraScreen extends StatelessWidget {
  const OrdenesCompraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    return ChangeNotifierProvider(
      create: (_) => OrdenesCompraProvider()
        ..init(auth)
        ..load(),
      child: Consumer<OrdenesCompraProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const _LoadingView();
          if (provider.error != null) {
            return _ErrorView(
              provider.error!,
              onRetry: provider.reload,
            );
          }
          return OrdenesCompraPage(provider: provider);
        },
      ),
    );
  }
}

// ── Empleados ─────────────────────────────────────────────────────────────────
class EmployeesScreen extends StatelessWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    return ChangeNotifierProvider(
      create: (_) => EmployeesProvider()
        ..init(auth)
        ..load(),
      child: Consumer<EmployeesProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const _LoadingView();
          if (provider.error != null) {
            return _ErrorView(provider.error!, onRetry: provider.reload);
          }
          return EmployeesPage(provider: provider);
        },
      ),
    );
  }
}

// ── Configuración ─────────────────────────────────────────────────────────────
class ConfigScreen extends StatelessWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    return ChangeNotifierProvider(
      create: (_) => ConfigProvider()
        ..init(auth)
        ..load(),
      child: Consumer<ConfigProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return const _LoadingView();
          if (provider.error != null) {
            return _ErrorView(provider.error!, onRetry: provider.reload);
          }
          return ConfigPage(provider: provider);
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
  final VoidCallback? onRetry;

  const _ErrorView(this.message, {this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: Color(0xFFDC2626), size: 40),
            const SizedBox(height: 12),
            const Text(
              'Error al cargar datos',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827)),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SinSucursalView extends StatelessWidget {
  const _SinSucursalView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF9FAFB),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_outlined, color: Color(0xFF9CA3AF), size: 40),
            SizedBox(height: 12),
            Text(
              'Sin sucursal asignada',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827)),
            ),
            SizedBox(height: 4),
            Text(
              'Tu usuario no tiene una sucursal activa.\nContacta al administrador.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}