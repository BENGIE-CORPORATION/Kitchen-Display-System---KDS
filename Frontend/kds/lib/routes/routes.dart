class TRoutes {
  static const login = '/login';
  static const forgetpassword = '/forgetpassword';
  static const resetpassword = '/resetpassword';

  static const home = '/';
  static const employee = '/employee';
  //pendiente la parte de app de empleados
  static const kitchendisplay = '/kitchendisplay';
  //pendiente la parte de kitchen display
  
  static const admin = '/admin';
  static const dashboard = '/admin/dashboard';
  static const sales = '/admin/sales';
  static const mainarea = '/admin/mainarea';
  static const caja = '/admin/caja';
  static const inventory = '/admin/inventory';
  static const providers = '/admin/providers';
  static const menu = '/admin/menu';
  static const employees = '/admin/employees';
  static const config = '/admin/config';
  static const profile = '/admin/profile';
  static const ordenes = '/admin/ordenes';

  static List sidebarMenuItems = [
    dashboard, 
    sales, 
    mainarea, 
    caja, 
    inventory, 
    providers, 
    menu, 
    employees, 
    config, 
    profile,
    ordenes
  ];
}