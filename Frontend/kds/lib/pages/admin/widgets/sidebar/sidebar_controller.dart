import 'package:flutter/material.dart';
import '../../../../routes/routes.dart';

class SidebarController extends ChangeNotifier {

  String _activeItem = TRoutes.admin;
  String _hoverItem = '';

  String get activeItem => _activeItem;
  String get hoverItem => _hoverItem;

  void changeActiveItem(String route) {
    _activeItem = route;
    notifyListeners();
  }

  void changeHoverItem(String route) {
    if (_activeItem != route) {
      _hoverItem = route;
      notifyListeners();
    }
  }

  bool isActive(String route) => _activeItem == route;
  bool isHovering(String route) => _hoverItem == route;

      

    void menuOnTap(BuildContext context, String route) {
    if (!isActive(route)) {
      changeActiveItem(route);
      //esto lo tiene el mae del tuto minuto 20 (https://www.youtube.com/watch?v=WchD9fNkHII&list=PL5jb9EteFAOAIr7tjUpz1n-_szVSx8JVz&index=11): if(TDeviveUtils.isMobileScreen(Get.context!)) Get.back();
      Navigator.pushNamed(context, route);
    }
  }
}