import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/admin/admin_layout.dart';
import '../pages/admin/dashboard/dashboard_page.dart';
import '../pages/admin/caja/caja_page.dart';
import '../pages/admin/config/config_page.dart';
import '../pages/admin/employees/employees_page.dart';
import '../pages/admin/inventory/inventory_page.dart';
import '../pages/admin/mainArea/mainArea_page.dart';
import '../pages/admin/menu/menu_page.dart';
import '../pages/admin/providers/providers_page.dart';
import '../pages/admin/sales/sales_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/admin',
  routes: [
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminLayout(),
      routes: [
        GoRoute(
          path: '',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: 'caja',
          builder: (context, state) => const CajaPage(),
        ),
        GoRoute(
          path: 'config',
          builder: (context, state) => const ConfigPage(),
        ),
        GoRoute(
          path: 'employees',
          builder: (context, state) => const EmployeesPage(),
        ),
        GoRoute(
          path: 'inventory',
          builder: (context, state) => const InventoryPage(),
        ),
        GoRoute(
          path: 'mainArea',
          builder: (context, state) => const MainAreaPage(),
        ),
        GoRoute(
          path: 'menu',
          builder: (context, state) => const MenuPage(),
        ),
        GoRoute(
          path: 'providers',
          builder: (context, state) => const ProvidersPage(),
        ),
        GoRoute(
          path: 'sales',
          builder: (context, state) => const SalesPage(),
        ),
      ],
    ),
  ],
);