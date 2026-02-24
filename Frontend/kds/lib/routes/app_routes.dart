import 'package:flutter/material.dart';
import '../pages/login/login_page.dart';
import '../pages/home/home_page.dart';
import '../pages/admin/dashboard/dashboard_page.dart';
import '../pages/admin/caja/caja_page.dart';
import '../pages/admin/sales/sales_page.dart';
import '../pages/admin/config/config_page.dart';
import '../pages/admin/employees/employees_page.dart';
import '../pages/admin/inventory/inventory_page.dart';
import '../pages/admin/mainArea/mainArea_page.dart';
import '../pages/admin/menu/menu_page.dart';
import '../pages/admin/providers/providers_page.dart';
import '../pages/admin/admin_layout.dart';
import 'routes.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> routes = {
    TRoutes.login: (context) => const LoginPage(),
    TRoutes.home: (context) => const HomePage(),
    
    // ADMIN ROUTES
    TRoutes.caja: (context) => const CajaPage(),
    TRoutes.config: (context) => const ConfigPage(),
    TRoutes.dashboard: (context) => const DashboardPage(),
    TRoutes.employees: (context) => const EmployeesPage(),
    TRoutes.inventory: (context) => const InventoryPage(),
    TRoutes.mainarea: (context) => const MainAreaPage(),
    TRoutes.menu: (context) => const MenuPage(),
    TRoutes.providers: (context) => const ProvidersPage(),
    TRoutes.sales: (context) => const SalesPage(),
    

    // SOLO ESTA
    TRoutes.admin: (context) => const AdminLayout(),
  };
}