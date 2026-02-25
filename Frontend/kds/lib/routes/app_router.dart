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
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: TRoutes.caja,
          builder: (context, state) => const CajaPage(),
        ),
        GoRoute(
          path: TRoutes.config,
          builder: (context, state) => const ConfigPage(),
        ),
        GoRoute(
          path: TRoutes.employees,
          builder: (context, state) => const EmployeesPage(),
        ),
        GoRoute(
          path: TRoutes.inventory,
          builder: (context, state) => const InventoryPage(),
        ),
        GoRoute(
          path: TRoutes.mainarea,
          builder: (context, state) => const MainAreaPage(),
        ),
        GoRoute(
          path: TRoutes.menu,
          builder: (context, state) => const MenuPage(),
        ),
        GoRoute(
          path: TRoutes.providers,
          builder: (context, state) => const ProvidersPage(),
        ),
        GoRoute(
          path: TRoutes.sales,
          builder: (context, state) => const SalesPage(),
        ),
      ],
    ),
  ],
);