import 'package:go_router/go_router.dart';

import '../pages/adminPanel/admin_layout.dart';
import '../pages/adminPanel/dashboard/dashboard_page.dart';
import '../pages/adminPanel/caja/caja_page.dart';
import '../pages/adminPanel/config/config_page.dart';
import '../pages/adminPanel/employees/employees_page.dart';
import '../pages/adminPanel/inventory/inventory_page.dart';
import '../pages/adminPanel/mainArea/mainArea_page.dart';
import '../pages/adminPanel/menu/menu_page.dart';
import '../pages/adminPanel/suppliers/suppliers_page.dart';
import '../pages/adminPanel/sales/sales_page.dart';
import '../pages/adminPanel/page_wrappers.dart';
import '../pages/home/home_page.dart';
import '../routes/routes.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: TRoutes.home,
  routes: [

    //HOME
    GoRoute(
      path: TRoutes.home,
      builder: (context, state) => const HomePage(),
    ),
    ShellRoute(
      builder: (context, state, child) {
        return AdminLayout(child: child);
      },
      routes: [
        GoRoute(
          path: TRoutes.admin,
          builder: (context, state) => DashboardPage(key: state.pageKey),
        ),
        GoRoute(
          path: TRoutes.caja,
          builder: (context, state) => CajaPage(key: state.pageKey),
        ),
        GoRoute(
          path: TRoutes.config,
          builder: (context, state) => ConfigPage(key: state.pageKey),
        ),
        GoRoute(
          path: TRoutes.employees,
          builder: (context, state) => EmployeesPage(key: state.pageKey),
        ),
        GoRoute(
          path: TRoutes.menu,
          builder: (context, state) => MenuPage(key: state.pageKey),
        ),

        // ── Pages con datos del backend ──────────────────────────────────
        // Cada Screen registra su propio Provider y maneja loading/error
        GoRoute(
          path: TRoutes.inventory,
          builder: (context, state) => InventoryScreen(key: state.pageKey),
        ),
        GoRoute(
          path: TRoutes.mainarea,
          builder: (context, state) => MainAreaScreen(key: state.pageKey),
        ),
        GoRoute(
          path: TRoutes.providers,
          builder: (context, state) => ProvidersScreen(key: state.pageKey),
        ),
        GoRoute(
          path: TRoutes.sales,
          builder: (context, state) => SalesScreen(key: state.pageKey),
        ),
      ],
    ),
  ],
);