// ─── SALES ────────────────────────────────────────────────────────────────────
class SaleItem {
  final String id;
  final String clave;
  final String nombre;
  int cantidad;
  final double precio;

  SaleItem({
    required this.id,
    required this.clave,
    required this.nombre,
    required this.cantidad,
    required this.precio,
  });

  double get total => cantidad * precio;

  factory SaleItem.fromJson(Map<String, dynamic> json) => SaleItem(
        id: json['id'].toString(),
        clave: json['clave'],
        nombre: json['nombre'],
        cantidad: json['cantidad'],
        precio: (json['precio'] as num).toDouble(),
      );

  Map<String, dynamic> toTableRow() => {
        'clave': clave,
        'nombre': nombre,
        'cantidad': cantidad,
        'precio': precio,
        'total': total,
        '_ref': this, // referencia para acciones
      };
}

class Product {
  final String clave;
  final String nombre;
  final double precio;

  const Product({
    required this.clave,
    required this.nombre,
    required this.precio,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        clave: json['clave'],
        nombre: json['nombre'],
        precio: (json['precio'] as num).toDouble(),
      );
}

// ─── SALON ────────────────────────────────────────────────────────────────────
enum TableStatus { available, occupied, reserved }

class TableModel {
  final int tableNumber;
  final TableStatus status;
  final int? people;
  final double? total;
  final String? reservationName;
  final String? reservationTime;

  const TableModel({
    required this.tableNumber,
    required this.status,
    this.people,
    this.total,
    this.reservationName,
    this.reservationTime,
  });

  factory TableModel.fromJson(Map<String, dynamic> json) => TableModel(
        tableNumber: json['tableNumber'],
        status: TableStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => TableStatus.available,
        ),
        people: json['people'],
        total: json['total'] != null ? (json['total'] as num).toDouble() : null,
        reservationName: json['reservationName'],
        reservationTime: json['reservationTime'],
      );
}

// ─── SUPPLIERS ────────────────────────────────────────────────────────────────
enum SupplierStatus { active, inactive }

class Supplier {
  final String id;
  final String name;
  final String legalId;
  final String phone;
  final String email;
  final String category;
  final SupplierStatus status;
  final DateTime lastPurchase;
  final double monthlyTotal;

  const Supplier({
    required this.id,
    required this.name,
    required this.legalId,
    required this.phone,
    required this.email,
    required this.category,
    required this.status,
    required this.lastPurchase,
    required this.monthlyTotal,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: json['id'].toString(),
        name: json['name'],
        legalId: json['legalId'],
        phone: json['phone'],
        email: json['email'],
        category: json['category'],
        status: json['status'] == 'active'
            ? SupplierStatus.active
            : SupplierStatus.inactive,
        lastPurchase: DateTime.parse(json['lastPurchase']),
        monthlyTotal: (json['monthlyTotal'] as num).toDouble(),
      );

  Map<String, dynamic> toTableRow() => {
        'name': name,
        'legalId': legalId,
        'contact': '$phone\n$email',
        'category': category,
        'status': status.name,
        'lastPurchase': lastPurchase,
        'monthlyTotal': monthlyTotal,
        '_ref': this,
      };
}

// ─── INVENTORY ────────────────────────────────────────────────────────────────
enum StockStatus { low, available }

class InventoryItem {
  final String id;
  final String name;
  final String unit;
  final String category;
  final double currentStock;
  final double minStock;
  final double unitCost;
  final StockStatus status;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.category,
    required this.currentStock,
    required this.minStock,
    required this.unitCost,
    required this.status,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'].toString(),
        name: json['name'],
        unit: json['unit'],
        category: json['category'],
        currentStock: (json['currentStock'] as num).toDouble(),
        minStock: (json['minStock'] as num).toDouble(),
        unitCost: (json['unitCost'] as num).toDouble(),
        status: json['status'] == 'low' ? StockStatus.low : StockStatus.available,
      );

  Map<String, dynamic> toTableRow() => {
        'name': name,
        'unit': unit,
        'category': category,
        'currentStock': currentStock,
        'minStock': minStock,
        'unitCost': unitCost,
        'status': status.name,
        '_ref': this,
      };
}
