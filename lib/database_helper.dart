import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models/item.dart';
import 'models/sale.dart';
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
      version: 8,
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
      'quantity INTEGER, '
      'photo_path TEXT'
      ')',
    );
    await _createTransactionsTable(db);
    await _createKhataTable(db);
    await _createSalesTable(db);
    await _createExpensesTable(db);
    await _createCashSessionsTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createTransactionsTable(db);
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE items ADD COLUMN photo_path TEXT');
    }
    if (oldVersion < 4) {
      await _createKhataTable(db);
    }
    if (oldVersion < 5) {
      await _createSalesTable(db);
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN sale_id INTEGER REFERENCES sales(id)',
      );
      await _createExpensesTable(db);
      await _createCashSessionsTable(db);
    }
    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE khata_entries ADD COLUMN sale_id INTEGER REFERENCES sales(id)',
      );
    }
    if (oldVersion < 7) {
      await db.execute(
        'ALTER TABLE sales ADD COLUMN discount_amount REAL NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 8) {
      await db.execute(
        'ALTER TABLE sales ADD COLUMN is_returned INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  Future<void> _createSalesTable(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS sales ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'customer_id INTEGER, '
      'total_amount REAL NOT NULL DEFAULT 0, '
      'paid_amount REAL NOT NULL DEFAULT 0, '
      'khata_amount REAL NOT NULL DEFAULT 0, '
      'discount_amount REAL NOT NULL DEFAULT 0, '
      'payment_method TEXT NOT NULL DEFAULT "cash", '
      'status TEXT NOT NULL DEFAULT "draft", '
      'timestamp INTEGER NOT NULL, '
      'is_returned INTEGER NOT NULL DEFAULT 0, '
      'FOREIGN KEY (customer_id) REFERENCES customers(id)'
      ')',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_status ON sales(status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_timestamp ON sales(timestamp)',
    );
  }

  Future<void> _createKhataTable(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS customers ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL, '
      'phone TEXT, '
      'created_at INTEGER NOT NULL'
      ')',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS khata_entries ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'customer_id INTEGER NOT NULL, '
      'type TEXT NOT NULL, '
      'amount REAL NOT NULL, '
      'note TEXT, '
      'timestamp INTEGER NOT NULL, '
      'sale_id INTEGER, '
      'FOREIGN KEY (customer_id) REFERENCES customers(id), '
      'FOREIGN KEY (sale_id) REFERENCES sales(id)'
      ')',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_khata_customer '
      'ON khata_entries(customer_id)',
    );
  }

  Future<void> _createExpensesTable(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS expenses ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'category TEXT NOT NULL, '
      'amount REAL NOT NULL, '
      'note TEXT, '
      'timestamp INTEGER NOT NULL'
      ')',
    );
  }

  Future<void> _createCashSessionsTable(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS cash_sessions ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'opening_cash REAL NOT NULL, '
      'closing_cash REAL, '
      'expected_cash REAL, '
      'discrepancy REAL, '
      'opened_at INTEGER NOT NULL, '
      'closed_at INTEGER, '
      'notes TEXT'
      ')',
    );
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
      'sale_id INTEGER, '
      'FOREIGN KEY (item_id) REFERENCES items(id), '
      'FOREIGN KEY (sale_id) REFERENCES sales(id)'
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
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_sale_id '
      'ON transactions(sale_id)',
    );
  }

  // ─── Items ───────────────────────────────────────────────────────────────────

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

  Future<int> deleteItem(int id) async {
    final db = await database;
    return db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  Future<Item?> getItemById(int id) async {
    final db = await database;
    final maps = await db.query('items', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Item.fromMap(maps.first);
  }

  Future<List<Item>> getAllItems() async {
    final db = await database;
    final maps = await db.query('items', orderBy: 'name COLLATE NOCASE ASC');
    return maps.map((m) => Item.fromMap(m)).toList();
  }

  // ─── Transactions ─────────────────────────────────────────────────────────────

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

  // ─── Sales ────────────────────────────────────────────────────────────────────

  Future<int> insertSale(Sale sale) async {
    final db = await database;
    return db.insert('sales', sale.toMap());
  }

  Future<void> updateSale(Sale sale) async {
    final db = await database;
    await db.update('sales', sale.toMap(), where: 'id = ?', whereArgs: [sale.id]);
  }

  Future<Sale?> getDraftSale() async {
    final db = await database;
    final rows = await db.query(
      'sales',
      where: 'status = ?',
      whereArgs: [SaleStatus.draft.name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Sale.fromMap(rows.first);
  }

  Future<List<SaleTransaction>> getTransactionsForSale(int saleId) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
    return maps.map((m) => SaleTransaction.fromMap(m)).toList();
  }

  Future<void> deleteTransactionsForSale(int saleId) async {
    final db = await database;
    await db.delete('transactions', where: 'sale_id = ?', whereArgs: [saleId]);
  }

  Future<void> deleteSale(int id) async {
    final db = await database;
    await db.delete('sales', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Sale>> getSalesByCustomer(int customerId) async {
    final db = await database;
    final rows = await db.query(
      'sales',
      where: 'customer_id = ? AND status = ?',
      whereArgs: [customerId, SaleStatus.completed.name],
      orderBy: 'timestamp DESC',
    );
    return rows.map((r) => Sale.fromMap(r)).toList();
  }


  Future<List<Sale>> getAllCompletedSales() async {
    final db = await database;
    final rows = await db.query(
      'sales',
      where: 'status = ?',
      whereArgs: [SaleStatus.completed.name],
      orderBy: 'timestamp DESC',
    );
    return rows.map((r) => Sale.fromMap(r)).toList();
  }

  Future<Sale?> getSaleById(int id) async {
    final db = await database;
    final rows = await db.query('sales', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Sale.fromMap(rows.first);
  }

  Future<void> processReturn({
    required int saleId,
    required int? customerId,
    required double saleTotal,
    required double saleKhata,
    required List<SaleTransaction> items,
    required Map<int, int> returnQuantities,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final item in items) {
        final returnQty = returnQuantities[item.itemId] ?? 0;
        if (returnQty <= 0) continue;

        await txn.rawUpdate(
          'UPDATE items SET quantity = quantity + ? WHERE id = ?',
          [returnQty, item.itemId],
        );

        await txn.insert('transactions', {
          'item_id': item.itemId,
          'item_name': item.itemName,
          'type': TransactionType.return_.name,
          'quantity': returnQty,
          'unit_cost': item.unitCost,
          'unit_price': item.unitPrice,
          'revenue': -(item.unitPrice * returnQty),
          'cost': -(item.unitCost * returnQty),
          'profit': -((item.unitPrice - item.unitCost) * returnQty),
          'timestamp': now,
          'sale_id': saleId,
        });
      }

      // Proportional khata reduction
      if (customerId != null && saleKhata > 0 && saleTotal > 0) {
        double returnTotal = 0;
        for (final item in items) {
          final qty = returnQuantities[item.itemId] ?? 0;
          returnTotal += item.unitPrice * qty;
        }
        final khataCredit = (returnTotal / saleTotal) * saleKhata;
        if (khataCredit > 0) {
          await txn.insert('khata_entries', {
            'customer_id': customerId,
            'type': 'payment',
            'amount': khataCredit,
            'note': 'Return — Sale #$saleId',
            'timestamp': now,
            'sale_id': saleId,
          });
        }
      }

      await txn.update(
        'sales',
        {'is_returned': 1},
        where: 'id = ?',
        whereArgs: [saleId],
      );
    });
  }

  Future<List<Sale>> getCompletedSalesBetween(DateTime start, DateTime end) async {
    final db = await database;
    final rows = await db.query(
      'sales',
      where: 'status = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [
        SaleStatus.completed.name,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
      orderBy: 'timestamp DESC',
    );
    return rows.map((r) => Sale.fromMap(r)).toList();
  }
}
