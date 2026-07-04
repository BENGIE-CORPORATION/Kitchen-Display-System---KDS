import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../routes/routes.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import 'menu/menu_item.dart';
import 'package:kds/common/widgets/sucursal_selector.dart';

class TSidebar extends StatelessWidget {
  final String currentRoute;

  const TSidebar({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      width: 260,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: TColors.white,
        border: Border(
          right: BorderSide(color: TColors.grey, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(TSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const SizedBox(height: 30),

              Text(
                'RestaurantePOS',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge!
                    .apply(letterSpacingDelta: 1.2),
              ),

              Text(
                'Panel de Administración',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .apply(letterSpacingDelta: 1.2),
              ),

              // selector de sucursal (solo visible para super_admin)
              const SucursalSelector(),

              const SizedBox(height: 30),

              _buildMenuItem(context, TRoutes.admin, "Dashboard"),
              _buildMenuItem(context, TRoutes.mainarea, "REVIEW: Área Principal (mesas)"),
              _buildMenuItem(context, TRoutes.sales, "Ventas"),
              _buildMenuItem(context, TRoutes.caja, "Cajas"),
              _buildMenuItem(context, TRoutes.menu, "Menú"),
              _buildMenuItem(context, TRoutes.inventory, "FIX: Inventario"),
              _buildMenuItem(context, TRoutes.providers, "FIX: Proveedores"),
              _buildMenuItem(context, TRoutes.ordenes, "FIX: Órdenes de Compra"),
              _buildMenuItem(context, TRoutes.employees, "DUDOSO: Empleados"),
              //_buildMenuItem(context, TRoutes.clientes, "NI: Clientes"),
              _buildMenuItem(context, TRoutes.config, "REVIEW: Configuración"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
      BuildContext context,
      String route,
      String title,
      ) {
    return TMenuItem(
      route: route,
      icon: Icons.dashboard,
      itemName: title,
      isActive: currentRoute == route,
      onTap: () => context.go(route),
    );
  }
}