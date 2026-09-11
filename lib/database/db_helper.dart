import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/transaction.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._internal();
  static Database? _db;

  DBHelper._internal();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'warung_kasir.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
  CREATE TABLE products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    barcode TEXT,
    name TEXT NOT NULL,
    price REAL NOT NULL,
    capital_price REAL NOT NULL DEFAULT 0,
    stock INTEGER NOT NULL DEFAULT 0,
    unit TEXT DEFAULT 'pcs',
    created_at TEXT NOT NULL
  )
''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice TEXT NOT NULL,
        total REAL NOT NULL,
        paid REAL NOT NULL,
        change REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        price REAL NOT NULL,
        qty INTEGER NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions(id)
      )
    ''');
  }

  // ============ PRODUCT CRUD ============

  Future<List<Product>> getProducts({String? search}) async {
    final db = await database;
    List<Map<String, dynamic>> maps;
    if (search != null && search.isNotEmpty) {
      maps = await db.query(
        'products',
        where: 'name LIKE ? OR barcode LIKE ?',
        whereArgs: ['%%', '%%'],
        orderBy: 'name ASC',
      );
    } else {
      maps = await db.query('products', orderBy: 'name ASC');
    }
    return maps.map((e) => Product.fromMap(e)).toList();
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;
    final map = product.toMap();
    map.remove('id');
    return await db.insert('products', map);
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateStock(int productId, int qty) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE products SET stock = stock - ? WHERE id = ?',
      [qty, productId],
    );
  }

  // ============ TRANSACTION CRUD ============

  Future<int> insertTransaction(Transaction tx) async {
    final db = await database;
    final txMap = tx.toMap();
    txMap.remove('id');
    final txId = await db.insert('transactions', txMap);

    for (final item in tx.items) {
      final itemMap = item.toMap();
      itemMap.remove('id');
      itemMap['transaction_id'] = txId;
      await db.insert('transaction_items', itemMap);
      await updateStock(item.productId, item.qty);
    }

    return txId;
  }

  Future<List<Transaction>> getTransactions() async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      orderBy: 'created_at DESC',
    );
    return maps.map((e) => Transaction.fromMap(e)).toList();
  }

  Future<Transaction?> getTransactionDetail(int id) async {
    final db = await database;
    final txMaps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (txMaps.isEmpty) return null;

    final tx = Transaction.fromMap(txMaps.first);
    final itemMaps = await db.query(
      'transaction_items',
      where: 'transaction_id = ?',
      whereArgs: [id],
    );
    final items = itemMaps.map((e) => TransactionItem.fromMap(e)).toList();
    return Transaction(
      id: tx.id,
      invoice: tx.invoice,
      total: tx.total,
      paid: tx.paid,
      change: tx.change,
      createdAt: tx.createdAt,
      items: items,
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    await db.delete(
      'transaction_items',
      where: 'transaction_id = ?',
      whereArgs: [id],
    );
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
