class Transaction {
  final int? id;
  final String invoice;
  final double total;
  final double paid;
  final double change;
  final String createdAt;
  List<TransactionItem> items;

  Transaction({
    this.id,
    required this.invoice,
    required this.total,
    required this.paid,
    required this.change,
    required this.createdAt,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice': invoice,
      'total': total,
      'paid': paid,
      'change': change,
      'created_at': createdAt,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      invoice: map['invoice'],
      total: map['total'],
      paid: map['paid'],
      change: map['change'],
      createdAt: map['created_at'],
    );
  }
}

class TransactionItem {
  final int? id;
  final int transactionId;
  final int productId;
  final String productName;
  final double price;
  final int qty;
  final double subtotal;

  TransactionItem({
    this.id,
    required this.transactionId,
    required this.productId,
    required this.productName,
    required this.price,
    required this.qty,
    required this.subtotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'qty': qty,
      'subtotal': subtotal,
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id'],
      transactionId: map['transaction_id'],
      productId: map['product_id'],
      productName: map['product_name'],
      price: map['price'],
      qty: map['qty'],
      subtotal: map['subtotal'],
    );
  }
}
