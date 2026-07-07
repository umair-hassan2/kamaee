import 'package:flutter_test/flutter_test.dart';
import 'package:kamaae/database_helper.dart';
import 'package:kamaae/models/transaction.dart';

import 'helpers/test_database.dart';

void main() {
  late DatabaseHelper db;

  setUp(() async {
    await setUpTestDatabase();
    db = DatabaseHelper();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('stores and finds item by barcode', () async {
    await insertTestItem(db, barcode: 'EAN-001', name: 'Rice');

    final found = await db.getItemByBarcode('EAN-001');

    expect(found, isNotNull);
    expect(found!.name, 'Rice');
  });

  test('returns null for unknown barcode', () async {
    final found = await db.getItemByBarcode('missing');
    expect(found, isNull);
  });

  test('logs and queries transactions in date range', () async {
    final item = await insertTestItem(db);
    final now = DateTime.now();

    await db.insertTransaction(
      SaleTransaction(
        itemId: item.id!,
        itemName: item.name,
        type: TransactionType.sell,
        quantity: 1,
        unitCost: 50,
        unitPrice: 100,
        revenue: 100,
        cost: 50,
        profit: 50,
        timestamp: now,
      ),
    );

    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final txs = await db.getTransactionsBetween(start, end);

    expect(txs, hasLength(1));
    expect(txs.first.profit, 50);
  });

  test('deletes item by id', () async {
    final item = await insertTestItem(db, barcode: 'DEL-001');

    final deleted = await db.deleteItem(item.id!);
    final found = await db.getItemByBarcode('DEL-001');

    expect(deleted, 1);
    expect(found, isNull);
  });
}
