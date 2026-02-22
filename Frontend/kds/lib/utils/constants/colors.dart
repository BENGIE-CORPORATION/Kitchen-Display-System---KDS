import 'package:flutter/material.dart';

class TColors {
  TColors._(); // Constructor privado para evitar instancias

  // ===============================
  // COLORES PRINCIPALES
  // ===============================

  static const Color primary = Color(0xFF6C5DD3);
  static const Color secondary = Color(0xFF00C2FF);
  static const Color accent = Color(0xFFFFB547);

  // ===============================
  // COLORES NEUTROS
  // ===============================

  static const Color white = Colors.white;
  static const Color black = Colors.black;

  static const Color greyLight = Color(0xFFF5F5F5);
  static const Color grey = Color(0xFFBDBDBD);
  static const Color greyDark = Color(0xFF616161);

  // ===============================
  // ESTADOS
  // ===============================

  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // ===============================
  // ADMIN PANEL
  // ===============================

  static const Color sidebarBackground = Color(0xFFFFFFFF);
  static const Color pageBackground = Color(0xFFF4F6F9);
  static const Color cardBackground = Color(0xFFFFFFFF);

  static const Color activeMenuItem = primary;
}