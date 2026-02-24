import 'package:flutter/material.dart';
import '../../routes/routes.dart';
import 'widgets/sidebar/sidebar.dart';
import 'dashboard/dashboard_page.dart';
import 'sales/sales_page.dart';
import 'caja/caja_page.dart';
import 'config/config_page.dart';
import 'inventory/inventory_page.dart';
import 'providers/providers_page.dart';
import 'menu/menu_page.dart';
import 'mainArea/mainArea_page.dart';
import 'employees/employees_page.dart';

class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {

  String currentRoute = TRoutes.dashboard;

  Widget getSelectedPage() {
  switch (currentRoute) {
    case TRoutes.dashboard:
      return const DashboardPage();

    case TRoutes.sales:
      return const SalesPage();

    case TRoutes.menu:
      return const MenuPage();

    case TRoutes.inventory:
      return const InventoryPage();

    case TRoutes.providers:
      return const ProvidersPage();

    case TRoutes.caja:
      return const CajaPage();

    case TRoutes.mainarea:
      return const MainAreaPage();

    case TRoutes.employees:
      return const EmployeesPage();

    case TRoutes.config:
      return const ConfigPage();

    default:
      return const DashboardPage();
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [

          TSidebar(
            currentRoute: currentRoute,
            onItemSelected: (route) {
              setState(() {
                currentRoute = route;
              });
            },
          ),

          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: getSelectedPage(),
            ),
          ),
        ],
      ),
    );
  }
}