import 'package:flutter/material.dart';
import '../pages/login/login_page.dart';
import '../pages/home/home_page.dart';
import '../pages/admin/admin_page.dart';
import 'routes.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> routes = {
    TRoutes.login: (context) => const LoginPage(),
    TRoutes.home: (context) => const HomePage(),
    TRoutes.admin: (context) => const AdminPage(),
  };
}