import 'package:flutter_test/flutter_test.dart';
import 'package:kamaae/database_helper.dart';
import 'package:kamaae/models/stock_count.dart';
import 'package:kamaae/services/stock_count_service.dart';

import 'helpers/test_database.dart';

void main() {
  late StockCountService service;
  late DatabaseHelper db;

  setUp(() async {
    await setUpTestDatabase();
    service = StockCountService();
    service.clearPendingCounts();
    db = DatabaseHelper();
  });

  tearDown(() async {
    service.clearPendingCounts();
    await tearDownTestDatabase();
  });

  group('pending count state', () {
    test('setPendingCount adds and overwrites entries', () async {
      service.setPendingCount(1, 5);
      service.setPendingCount(2, 3);
      service.setPendingCount(1, 7);

      expect(service.pendingCounts.value, {1: 7, 2: 3});
    });

    test('removePendingCount drops a single entry', () async {
      service.setPendingCount(1, 5);
      service.setPendingCount(2, 3);
      service.removePendingCount(1);

      expect(service.pendingCounts.value, {2: 3});
    });

    test('pendingCounts notifies listeners on change', () async {
      var notifications = 0;
      void listener() => notifications++;
      service.pendingCounts.addListener(listener);
      addTearDown(() => service.pendingCounts.removeListener(listener));

      service.setPendingCount(1, 5);
      service.removePendingCount(1);

      expect(notifications, 2);
    });
  });

  group('submitPendingCounts', () {
    test('records variance against current system quantity', () async {
      final item = await insertTestItem(db, quantity: 10);
      service.setPendingCount(item.id!, 7);

      final recorded = await service.submitPendingCounts();

      expect(recorded.length, 1);
      expect(recorded.first.itemId, item.id);
      expect(recorded.first.itemName, item.name);
      expect(recorded.first.systemQty, 10);
      expect(recorded.first.physicalQty, 7);
      expect(recorded.first.variance, -3);
      expect(recorded.first.isShort, isTrue);
    });

    test('clears pending counts on success', () async {
      final item = await insertTestItem(db, quantity: 10);
      service.setPendingCount(item.id!, 10);

      await service.submitPendingCounts();

      expect(service.pendingCounts.value, isEmpty);
    });

    test('returns recorded rows worst shortage first', () async {
      final short = await insertTestItem(db, barcode: 'a', name: 'Short', quantity: 10);
      final exact = await insertTestItem(db, barcode: 'b', name: 'Exact', quantity: 5);
      final over = await insertTestItem(db, barcode: 'c', name: 'Over', quantity: 2);

      service.setPendingCount(exact.id!, 5);
      service.setPendingCount(over.id!, 4);
      service.setPendingCount(short.id!, 1);

      final recorded = await service.submitPendingCounts();

      expect(recorded.map((c) => c.itemName), ['Short', 'Exact', 'Over']);
      expect(recorded.map((c) => c.variance), [-9, 0, 2]);
    });

    test('commits no rows when one item is missing', () async {
      final item = await insertTestItem(db, quantity: 10);
      service.setPendingCount(item.id!, 8);
      service.setPendingCount(999999, 4);

      await expectLater(service.submitPendingCounts(), throwsStateError);

      final history = await service.getLatestCountPerItem();
      expect(history, isEmpty);
    });

    test('retains pending counts when submission fails', () async {
      final item = await insertTestItem(db, quantity: 10);
      service.setPendingCount(item.id!, 8);
      service.setPendingCount(999999, 4);

      await expectLater(service.submitPendingCounts(), throwsStateError);

      expect(service.pendingCounts.value, {item.id!: 8, 999999: 4});
    });

    test('is a no-op when nothing is pending', () async {
      final recorded = await service.submitPendingCounts();
      expect(recorded, isEmpty);
      expect(await service.getLatestCountPerItem(), isEmpty);
    });

    test('records a zero physical count as a full shortage', () async {
      final item = await insertTestItem(db, quantity: 6);
      service.setPendingCount(item.id!, 0);

      final recorded = await service.submitPendingCounts();

      expect(recorded.first.physicalQty, 0);
      expect(recorded.first.variance, -6);
    });

    test('preserves prior counts when an item is counted again', () async {
      final item = await insertTestItem(db, quantity: 10);

      service.setPendingCount(item.id!, 8);
      await service.submitPendingCounts();
      service.setPendingCount(item.id!, 6);
      await service.submitPendingCounts();

      final history = await service.getCountHistoryForItem(item.id!);
      expect(history.length, 2);
      expect(history.map((c) => c.physicalQty), [8, 6]);
    });
  });

  group('getLatestCountPerItem', () {
    test('returns one row per item, worst shortage first', () async {
      final a = await insertTestItem(db, barcode: 'a', name: 'Alpha', quantity: 10);
      final b = await insertTestItem(db, barcode: 'b', name: 'Beta', quantity: 10);

      service.setPendingCount(a.id!, 9);
      service.setPendingCount(b.id!, 8);
      await service.submitPendingCounts();

      await _insertCountRow(
        db,
        itemId: a.id!,
        itemName: 'Alpha',
        systemQty: 10,
        physicalQty: 3,
        countedAt: DateTime.now().millisecondsSinceEpoch + 60000,
      );

      final latest = await service.getLatestCountPerItem();

      expect(latest.length, 2);
      expect(latest.first.itemName, 'Alpha');
      expect(latest.first.variance, -7);
      expect(latest.last.itemName, 'Beta');
      expect(latest.last.variance, -2);
    });

    test('returns empty when nothing has been counted', () async {
      expect(await service.getLatestCountPerItem(), isEmpty);
    });
  });

  group('getCountHistoryForItem', () {
    test('returns that item history oldest first', () async {
      final item = await insertTestItem(db, quantity: 10);
      final other = await insertTestItem(db, barcode: 'b', name: 'Other', quantity: 10);
      final base = DateTime.now().millisecondsSinceEpoch;

      await _insertCountRow(
        db,
        itemId: item.id!,
        itemName: item.name,
        systemQty: 10,
        physicalQty: 4,
        countedAt: base + 2000,
      );
      await _insertCountRow(
        db,
        itemId: item.id!,
        itemName: item.name,
        systemQty: 10,
        physicalQty: 9,
        countedAt: base,
      );
      await _insertCountRow(
        db,
        itemId: other.id!,
        itemName: other.name,
        systemQty: 10,
        physicalQty: 1,
        countedAt: base + 1000,
      );

      final history = await service.getCountHistoryForItem(item.id!);

      expect(history.map((c) => c.physicalQty), [9, 4]);
    });

    test('returns empty for an item never counted', () async {
      final item = await insertTestItem(db, quantity: 10);
      expect(await service.getCountHistoryForItem(item.id!), isEmpty);
    });
  });

  group('schema', () {
    test('rejects a row whose variance disagrees with the counts', () async {
      final item = await insertTestItem(db, quantity: 10);
      final database = await db.database;

      await expectLater(
        database.insert('stock_counts', {
          'item_id': item.id,
          'item_name': item.name,
          'system_qty': 10,
          'physical_qty': 4,
          'variance': 6,
          'counted_at': DateTime.now().millisecondsSinceEpoch,
        }),
        throwsA(isA<Exception>()),
      );
    });
  });

  test('StockCount.fromMap round-trips through toMap', () {
    const count = StockCount(
      id: 1,
      itemId: 2,
      itemName: 'Widget',
      systemQty: 10,
      physicalQty: 7,
      variance: -3,
      countedAt: 1700000000000,
    );
    final restored = StockCount.fromMap(count.toMap());

    expect(restored.id, count.id);
    expect(restored.itemId, count.itemId);
    expect(restored.itemName, count.itemName);
    expect(restored.systemQty, count.systemQty);
    expect(restored.physicalQty, count.physicalQty);
    expect(restored.variance, count.variance);
    expect(restored.countedAt, count.countedAt);
  });
}

Future<void> _insertCountRow(
  DatabaseHelper db, {
  required int itemId,
  required String itemName,
  required int systemQty,
  required int physicalQty,
  required int countedAt,
}) async {
  final database = await db.database;
  await database.insert('stock_counts', {
    'item_id': itemId,
    'item_name': itemName,
    'system_qty': systemQty,
    'physical_qty': physicalQty,
    'variance': physicalQty - systemQty,
    'counted_at': countedAt,
  });
}
