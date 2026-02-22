import 'package:flutter/material.dart';
import '../../../../routes/routes.dart';
import '../../../../utils/constants/colors.dart';
import 'menu/menu_item.dart';

class TSidebar extends StatelessWidget {
  final String currentRoute;

  const TSidebar({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
   return Drawer(
    shape: const BeveledRectangleBorder(),
    child: Container(
      decoration: const BoxDecoration(
        color: TColors.white,
        border: Border(right: BorderSide(color: TColors.grey, width: 1))
      ),
      child: SingleChildScrollView(
        child: Column (
          children: [
            SizedBox(height: 32.0),
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('RestaurantePOS', style: Theme.of(context).textTheme.bodyLarge!.apply(letterSpacingDelta: 1.2)),
                  Text('Panel de Administración', style: Theme.of(context).textTheme.bodySmall!.apply(letterSpacingDelta: 1.2)),

                  // Menu Items
                  TMenuItem(
                    route: TRoutes.dashboard,
                    icon: Icons.dashboard,
                    itemName: "Dashboard",
                    isActive: currentRoute == TRoutes.dashboard,
                    onTap: () {
                      Navigator.pushNamed(context, TRoutes.dashboard);
                    },
                  ),

                  TMenuItem(
                    route: TRoutes.sales,
                    icon: Icons.dashboard,
                    itemName: "Ventas",
                    isActive: currentRoute == TRoutes.sales,
                    onTap: () {
                      Navigator.pushNamed(context, TRoutes.sales);
                    },
                  ),

                  TMenuItem(
                    route: TRoutes.mainarea,
                    icon: Icons.dashboard,
                    itemName: "Salón Principal",
                    isActive: currentRoute == TRoutes.mainarea,
                    onTap: () {
                      Navigator.pushNamed(context, TRoutes.mainarea);
                    },
                  ),

                  TMenuItem(
                    route: TRoutes.caja,
                    icon: Icons.dashboard,
                    itemName: "Caja",
                    isActive: currentRoute == TRoutes.caja,
                    onTap: () {
                      Navigator.pushNamed(context, TRoutes.caja);
                    },
                  ),

                  TMenuItem(
                    route: TRoutes.inventory,
                    icon: Icons.dashboard,
                    itemName: "Inventario",
                    isActive: currentRoute == TRoutes.inventory,
                    onTap: () {
                      Navigator.pushNamed(context, TRoutes.inventory);
                    },
                  ),

                  TMenuItem(
                    route: TRoutes.providers,
                    icon: Icons.dashboard,
                    itemName: "Proveedores",
                    isActive: currentRoute == TRoutes.providers,
                    onTap: () {
                      Navigator.pushNamed(context, TRoutes.providers);
                    },
                  ),

                  TMenuItem(
                    route: TRoutes.menu,
                    icon: Icons.dashboard,
                    itemName: "Menú",
                    isActive: currentRoute == TRoutes.menu,
                    onTap: () {
                      Navigator.pushNamed(context, TRoutes.menu);
                    },
                  ),

                  TMenuItem(
                    route: TRoutes.employees,
                    icon: Icons.dashboard,
                    itemName: "Empleados",
                    isActive: currentRoute == TRoutes.employees,
                    onTap: () {
                      Navigator.pushNamed(context, TRoutes.employees);
                    },
                  ),
                  
                  TMenuItem(
                    route: TRoutes.config,
                    icon: Icons.dashboard,
                    itemName: "Configuración",
                    isActive: currentRoute == TRoutes.config,
                    onTap: () {
                      Navigator.pushNamed(context, TRoutes.config);
                    },
                  ),
                ],
              )
            ),
          ],
        )
      ),
    ),
   );
  }
}

