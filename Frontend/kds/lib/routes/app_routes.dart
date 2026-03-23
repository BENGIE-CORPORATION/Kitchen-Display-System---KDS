import 'package:flutter/material.dart';
import '../pages/login/login_page.dart';
import '../pages/home/home_page.dart';
import '../pages/adminPanel/dashboard/dashboard_page.dart';
import '../pages/adminPanel/caja/caja_page.dart';
import '../pages/adminPanel/config/config_page.dart';
import '../pages/adminPanel/employees/employees_page.dart';
import '../pages/adminPanel/page_wrappers.dart';
import '../pages/adminPanel/menu/menu_page.dart';
//import '../pages/admin/admin_layout.dart';
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
    TRoutes.inventory: (context) => const InventoryScreen(),
    TRoutes.mainarea: (context) => const MainAreaScreen(),
    TRoutes.menu: (context) => const MenuPage(),
    TRoutes.providers: (context) => const ProvidersScreen(),
    TRoutes.sales: (context) => const SalesScreen(),
    

    // SOLO ESTA
    //TRoutes.admin: (context) => const AdminLayout(),
  };
}