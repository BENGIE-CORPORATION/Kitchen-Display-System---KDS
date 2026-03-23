import 'package:flutter/material.dart';
import 'routes.dart';
import '../pages/adminPanel/widgets/sidebar/sidebar_controller.dart';

class AppRouteObserver extends RouteObserver<ModalRoute<void>> {

  final SidebarController sidebarController;

  AppRouteObserver(this.sidebarController);

  @override
  void didPop(Route route, Route? previousRoute) {
    if (previousRoute?.settings.name != null) {
      final previousRouteName = previousRoute!.settings.name!;

      if (TRoutes.sidebarMenuItems.contains(previousRouteName)) {
        sidebarController.changeActiveItem(previousRouteName);
      }
    }
  }
}