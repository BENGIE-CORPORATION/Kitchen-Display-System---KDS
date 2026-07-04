//import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
//import 'package:provider/provider.dart';

import '../pages/adminPanel/admin_layout.dart';
import '../pages/adminPanel/dashboard/dashboard_page.dart';
import '../pages/adminPanel/caja/caja_page.dart';
import '../pages/adminPanel/config/config_page.dart';
import '../pages/adminPanel/employees/employees_page.dart';
import '../pages/adminPanel/menu/menu_page.dart';
import '../pages/adminPanel/page_wrappers.dart';
import '../pages/home/home_page.dart';
import '../pages/login/login_page.dart';
import '../common/providers/auth_provider.dart';
import 'routes.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: TRoutes.login,
    refreshListenable: authProvider, // re-evalúa redirect cuando cambia AuthStatus

    redirect: (context, state) {
      final status = authProvider.status;
      final isLoginRoute = state.matchedLocation == TRoutes.login;
      final isHomeRoute  = state.matchedLocation == TRoutes.home;

      if (status == AuthStatus.checking) return null;

      if (status == AuthStatus.unauthenticated) {
        if (isLoginRoute || isHomeRoute) return null;
        return TRoutes.login;
      }

      if (status == AuthStatus.authenticated && isLoginRoute) {
        return TRoutes.home;
      }

      return null;
    },

    routes: [
      GoRoute(
        path: TRoutes.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: TRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),

      ShellRoute(
        builder: (context, state, child) => AdminLayout(child: child),
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
            builder: (context, state) => ConfigScreen(key: state.pageKey),
          ),
          GoRoute(
            path: TRoutes.employees,
            builder: (context, state) => EmployeesScreen(key: state.pageKey),
          ),
          GoRoute(
            path: TRoutes.menu,
            builder: (context, state) => MenuPage(key: state.pageKey),
          ),
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
            builder: (context, state) => SuppliersScreen(key: state.pageKey),
          ),
          GoRoute(
            path: TRoutes.sales,
            builder: (context, state) => SalesScreen(key: state.pageKey),
          ),
          GoRoute(
            path: TRoutes.ordenes,
            builder: (context, state) => OrdenesCompraScreen(key: state.pageKey),
          ),
        ],
      ),
    ],
  );
}