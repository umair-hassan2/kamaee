import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models/item.dart';
import 'models/transaction.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  @visibleForTesting
  static String? databasePathOverride;

  @visibleForTesting
  static Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = databasePathOverride ??
        join(await getDatabasesPath(), 'kamaae.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      'CREATE TABLE items ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'barcode TEXT UNIQUE, '
      'name TEXT, '
      'purchase_price REAL, '
      'selling_price REAL, '
      'quantity INTEGER'
      ')',
    );
    await _createTransactionsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createTransactionsTable(db);
    }
  }

  Future<void> _createTransactionsTable(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS transactions ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'item_id INTEGER NOT NULL, '
      'item_name TEXT NOT NULL, '
      'type TEXT NOT NULL, '
      'quantity INTEGER NOT NULL, '
      'unit_cost REAL NOT NULL, '
      'unit_price REAL NOT NULL, '
      'revenue REAL NOT NULL, '
      'cost REAL NOT NULL, '
      'profit REAL NOT NULL, '
      'timestamp INTEGER NOT NULL, '
      'FOREIGN KEY (item_id) REFERENCES items(id)'
      ')',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_timestamp '
      'ON transactions(timestamp)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_item_id '
      'ON transactions(item_id)',
    );
  }

  Future<Item?> getItemByBarcode(String barcode) async {
    final db = await database;
    final maps = await db.query(
      'items',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    if (maps.isEmpty) return null;
    return Item.fromMap(maps.first);
  }

  Future<int> insertItem(Item item) async {
    final db = await database;
    return db.insert('items', item.toMap());
  }

  Future<int> updateItem(Item item) async {
    final db = await database;
    return db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<List<Item>> getAllItems() async {
    final db = await database;
    final maps = await db.query('items', orderBy: 'name COLLATE NOCASE ASC');
    return maps.map((m) => Item.fromMap(m)).toList();
  }

  Future<int> insertTransaction(SaleTransaction transaction) async {
    final db = await database;
    return db.insert('transactions', transaction.toMap());
  }

  Future<List<SaleTransaction>> getTransactionsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => SaleTransaction.fromMap(m)).toList();
  }

  Future<List<Map<String, dynamic>>> getTransactionAggregatesBetween(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    return db.rawQuery(
      'SELECT type, quantity, revenue, cost, profit '
      'FROM transactions '
      'WHERE timestamp >= ? AND timestamp < ?',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
  }

  Future<List<Map<String, dynamic>>> getDailyAggregatesBetween(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    return db.rawQuery(
      'SELECT '
      '(timestamp / 86400000) AS day_bucket, '
      'SUM(CASE WHEN type = ? THEN revenue ELSE 0 END) AS revenue, '
      'SUM(CASE WHEN type = ? THEN profit ELSE 0 END) AS profit, '
      'SUM(CASE WHEN type = ? THEN cost ELSE 0 END) AS cogs, '
      'SUM(CASE WHEN type = ? THEN cost ELSE 0 END) AS restock '
      'FROM transactions '
      'WHERE timestamp >= ? AND timestamp < ? '
      'GROUP BY day_bucket '
      'ORDER BY day_bucket ASC',
      [
        TransactionType.sell.name,
        TransactionType.sell.name,
        TransactionType.sell.name,
        TransactionType.restock.name,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
    );
  }

  Future<List<Map<String, dynamic>>> getHourlyAggregatesBetween(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    return db.rawQuery(
      'SELECT '
      '(timestamp / 3600000) AS hour_bucket, '
      'SUM(CASE WHEN type = ? THEN revenue ELSE 0 END) AS revenue, '
      'SUM(CASE WHEN type = ? THEN profit ELSE 0 END) AS profit, '
      'SUM(CASE WHEN type = ? THEN cost ELSE 0 END) AS cogs '
      'FROM transactions '
      'WHERE timestamp >= ? AND timestamp < ? '
      'GROUP BY hour_bucket '
      'ORDER BY hour_bucket ASC',
      [
        TransactionType.sell.name,
        TransactionType.sell.name,
        TransactionType.sell.name,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
    );
  }

  Future<List<Map<String, dynamic>>> getTopProductsBetween(
    DateTime start,
    DateTime end, {
    int limit = 5,
  }) async {
    final db = await database;
    return db.rawQuery(
      'SELECT item_name, '
      'SUM(revenue) AS revenue, '
      'SUM(profit) AS profit, '
      'SUM(quantity) AS quantity '
      'FROM transactions '
      'WHERE type = ? AND timestamp >= ? AND timestamp < ? '
      'GROUP BY item_id, item_name '
      'ORDER BY revenue DESC '
      'LIMIT ?',
      [
        TransactionType.sell.name,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
        limit,
      ],
    );
  }
}
