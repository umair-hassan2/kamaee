import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kamaae/database_helper.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The stock_counts table must exist on fresh installs and on installs
/// upgraded from v8, or the first count submission throws.
void main() {
  late Directory tempDir;

  setUp(() async {
    await DatabaseHelper.closeDatabase();
    tempDir = await Directory.systemTemp.createTemp('kamaae_migration');
  });

  tearDown(() async {
    await DatabaseHelper.closeDatabase();
    DatabaseHelper.databasePathOverride = null;
    await tempDir.delete(recursive: true);
  });

  Future<bool> hasStockCountsTable() async {
    final db = await DatabaseHelper().database;
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      ['stock_counts'],
    );
    return rows.isNotEmpty;
  }

  test('fresh install creates the stock_counts table', () async {
    DatabaseHelper.databasePathOverride = join(tempDir.path, 'fresh.db');

    expect(await hasStockCountsTable(), isTrue);
  });

  test('upgrading from v8 creates the stock_counts table', () async {
    final path = join(tempDir.path, 'legacy.db');
    final legacy = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: (db, version) async {
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
        },
      ),
    );
    await legacy.close();

    DatabaseHelper.databasePathOverride = path;

    expect(await hasStockCountsTable(), isTrue);
  });

  test('upgrading twice leaves the table intact', () async {
    final path = join(tempDir.path, 'reopen.db');
    DatabaseHelper.databasePathOverride = path;

    final first = await DatabaseHelper().database;
    await first.insert('stock_counts', {
      'item_id': 1,
      'item_name': 'Sugar',
      'system_qty': 10,
      'physical_qty': 7,
      'variance': -3,
      'counted_at': DateTime.now().millisecondsSinceEpoch,
    });
    await DatabaseHelper.closeDatabase();

    final reopened = await DatabaseHelper().database;
    final rows = await reopened.query('stock_counts');

    expect(rows.length, 1);
    expect(rows.first['item_name'], 'Sugar');
  });
}
