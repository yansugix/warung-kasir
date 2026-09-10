class Product {
  final int? id;
  final String? barcode;
  final String name;
  final double price;
  final double capitalPrice; // harga modal
  final int stock;
  final String unit;
  final String createdAt;

  Product({
    this.id,
    this.barcode,
    required this.name,
    required this.price,
    this.capitalPrice = 0,
    required this.stock,
    this.unit = 'pcs',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'price': price,
      'capital_price': capitalPrice,
      'stock': stock,
      'unit': unit,
      'created_at': createdAt,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      barcode: map['barcode'],
      name: map['name'],
      price: map['price'],
      capitalPrice: map['capital_price'] ?? 0,
      stock: map['stock'],
      unit: map['unit'] ?? 'pcs',
      createdAt: map['created_at'],
    );
  }

  Product copyWith({
    int? id,
    String? barcode,
    String? name,
    double? price,
    double? capitalPrice,
    int? stock,
    String? unit,
    String? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      price: price ?? this.price,
      capitalPrice: capitalPrice ?? this.capitalPrice,
      stock: stock ?? this.stock,
      unit: unit ?? this.unit,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
