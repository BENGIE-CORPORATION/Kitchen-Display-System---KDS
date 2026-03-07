import '../models/models.dart';

// ─── SALES ────────────────────────────────────────────────────────────────────
class SalesMock {
  static List<Product> products = [
    Product(clave: '001', nombre: 'Hamburguesa Clásica', precio: 5500),
    Product(clave: '002', nombre: 'Pizza Margarita', precio: 8000),
    Product(clave: '003', nombre: 'Ensalada César', precio: 4500),
    Product(clave: '004', nombre: 'Refresco', precio: 1500),
    Product(clave: '005', nombre: 'Café', precio: 2000),
    Product(clave: '006', nombre: 'Pasta Alfredo', precio: 6500),
    Product(clave: '007', nombre: 'Tacos al Pastor', precio: 4000),
    Product(clave: '008', nombre: 'Burrito', precio: 5000),
    Product(clave: '009', nombre: 'Sándwich Club', precio: 4800),
    Product(clave: '010', nombre: 'Postre del Día', precio: 3500),
  ];

  static List<SaleItem> initialItems = [
    SaleItem(id: '1', clave: '001', nombre: 'Hamburguesa Clásica', cantidad: 2, precio: 5500),
    SaleItem(id: '2', clave: '002', nombre: 'Pizza Margarita', cantidad: 1, precio: 8000),
    SaleItem(id: '3', clave: '004', nombre: 'Refresco', cantidad: 3, precio: 1500),
  ];
}

// ─── SALON ────────────────────────────────────────────────────────────────────
class MainAreaMock {
  static List<TableModel> tables = [
    TableModel(tableNumber: 1, status: TableStatus.occupied, people: 4, total: 45000),
    TableModel(tableNumber: 2, status: TableStatus.available),
    TableModel(tableNumber: 3, status: TableStatus.occupied, people: 2, total: 28000),
    TableModel(tableNumber: 4, status: TableStatus.available),
    TableModel(tableNumber: 5, status: TableStatus.occupied, people: 6, total: 72000),
    TableModel(
      tableNumber: 6,
      status: TableStatus.reserved,
      reservationName: 'María González',
      reservationTime: 'Hoy - 01:56 p. m.',
    ),
    TableModel(tableNumber: 7, status: TableStatus.available),
    TableModel(tableNumber: 8, status: TableStatus.occupied, people: 3, total: 35000),
  ];
}

// ─── SUPPLIERS ────────────────────────────────────────────────────────────────
class SuppliersMock {
  static List<Supplier> suppliers = [
    Supplier(
      id: '1',
      name: 'Distribuidora El Agricultor S.A.',
      legalId: '3-101-234567',
      phone: '2222-3456',
      email: 'ventas@elagicultor.com',
      category: 'Vegetales',
      status: SupplierStatus.active,
      lastPurchase: DateTime(2025, 1, 28),
      monthlyTotal: 1250000,
    ),
    Supplier(
      id: '2',
      name: 'Carnes Premium Costa Rica',
      legalId: '3-101-345678',
      phone: '2222-4567',
      email: 'info@carnespremium.cr',
      category: 'Carnes',
      status: SupplierStatus.active,
      lastPurchase: DateTime(2025, 1, 30),
      monthlyTotal: 3450000,
    ),
    Supplier(
      id: '3',
      name: 'Bebidas y Licores La Central',
      legalId: '3-101-456789',
      phone: '2222-5678',
      email: 'pedidos@lacentral.com',
      category: 'Bebidas',
      status: SupplierStatus.active,
      lastPurchase: DateTime(2025, 1, 29),
      monthlyTotal: 890000,
    ),
    Supplier(
      id: '4',
      name: 'Insumos Gastronómicos Pacífico',
      legalId: '3-101-567890',
      phone: '2222-6789',
      email: 'contacto@pacifico.cr',
      category: 'Insumos',
      status: SupplierStatus.active,
      lastPurchase: DateTime(2025, 1, 25),
      monthlyTotal: 560000,
    ),
    Supplier(
      id: '5',
      name: 'Lácteos del Valle S.A.',
      legalId: '3-101-678901',
      phone: '2222-7890',
      email: 'ventas@lacteosvallle.com',
      category: 'Lácteos',
      status: SupplierStatus.inactive,
      lastPurchase: DateTime(2024, 12, 15),
      monthlyTotal: 0,
    ),
    Supplier(
      id: '6',
      name: 'Mariscos Frescos del Golfo',
      legalId: '3-101-789012',
      phone: '2222-8901',
      email: 'info@mariscosgolfo.cr',
      category: 'Mariscos',
      status: SupplierStatus.active,
      lastPurchase: DateTime(2025, 1, 31),
      monthlyTotal: 1890000,
    ),
  ];
}

// ─── INVENTORY ────────────────────────────────────────────────────────────────
class InventoryMock {
  static List<InventoryItem> items = [
    InventoryItem(id: '1', name: 'Tomate', unit: 'kg', category: 'Verduras', currentStock: 2, minStock: 10, unitCost: 2500, status: StockStatus.low),
    InventoryItem(id: '2', name: 'Lechuga', unit: 'unidades', category: 'Verduras', currentStock: 3, minStock: 8, unitCost: 1200, status: StockStatus.low),
    InventoryItem(id: '3', name: 'Cebolla', unit: 'kg', category: 'Verduras', currentStock: 15, minStock: 5, unitCost: 1800, status: StockStatus.available),
    InventoryItem(id: '4', name: 'Pollo', unit: 'kg', category: 'Carnes', currentStock: 25, minStock: 20, unitCost: 4500, status: StockStatus.available),
    InventoryItem(id: '5', name: 'Res', unit: 'kg', category: 'Carnes', currentStock: 18, minStock: 15, unitCost: 6500, status: StockStatus.available),
    InventoryItem(id: '6', name: 'Camarones', unit: 'kg', category: 'Mariscos', currentStock: 5, minStock: 8, unitCost: 12000, status: StockStatus.low),
    InventoryItem(id: '7', name: 'Salmón', unit: 'kg', category: 'Mariscos', currentStock: 12, minStock: 6, unitCost: 15000, status: StockStatus.available),
    InventoryItem(id: '8', name: 'Leche', unit: 'litros', category: 'Lácteos', currentStock: 20, minStock: 15, unitCost: 1500, status: StockStatus.available),
    InventoryItem(id: '9', name: 'Queso', unit: 'kg', category: 'Lácteos', currentStock: 8, minStock: 5, unitCost: 8500, status: StockStatus.available),
    InventoryItem(id: '10', name: 'Aceite de Oliva', unit: 'litros', category: 'Aceites', currentStock: 4, minStock: 6, unitCost: 9500, status: StockStatus.low),
    InventoryItem(id: '11', name: 'Arroz', unit: 'kg', category: 'Granos', currentStock: 50, minStock: 30, unitCost: 1800, status: StockStatus.available),
    InventoryItem(id: '12', name: 'Frijoles', unit: 'kg', category: 'Granos', currentStock: 35, minStock: 20, unitCost: 2200, status: StockStatus.available),
  ];
}