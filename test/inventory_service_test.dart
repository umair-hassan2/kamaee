import 'package:flutter_test/flutter_test.dart';
import 'package:kamaae/database_helper.dart';
import 'package:kamaae/models/transaction.dart';
import 'package:kamaae/services/inventory_service.dart';

import 'helpers/test_database.dart';

void main() {
  late InventoryService inventory;

  setUp(() async {
    await setUpTestDatabase();
    inventory = InventoryService();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('sell reduces stock and records transaction', () async {
    final item = await insertTestItem(
      DatabaseHelper(),
      quantity: 10,
      purchasePrice: 50,
      sellingPrice: 100,
    );

    final updated = await inventory.sellItem(item, 3);

    expect(updated.quantity, 7);

    final txs = await DatabaseHelper().getTransactionsBetween(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
          .add(const Duration(days: 1)),
    );

    expect(txs, hasLength(1));
    expect(txs.first.type, TransactionType.sell);
    expect(txs.first.revenue, 300);
    expect(txs.first.profit, 150);
  });

  test('sell throws when stock is insufficient', () async {
    final item = await insertTestItem(DatabaseHelper(), quantity: 1);

    expect(
      () => inventory.sellItem(item, 5),
      throwsA(isA<StateError>()),
    );
  });

  test('sell throws for invalid quantity', () async {
    final item = await insertTestItem(DatabaseHelper());

    expect(
      () => inventory.sellItem(item, 0),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('restock increases stock and records spend', () async {
    final item = await insertTestItem(
      DatabaseHelper(),
      quantity: 5,
      purchasePrice: 40,
    );

    final updated = await inventory.restockItem(item, 4);

    expect(updated.quantity, 9);

    final txs = await DatabaseHelper().getTransactionsBetween(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
          .add(const Duration(days: 1)),
    );

    expect(txs, hasLength(1));
    expect(txs.first.type, TransactionType.restock);
    expect(txs.first.cost, 160);
  });
}
