import 'package:flutter/foundation.dart';
import '../database_helper.dart';
import '../models/stock_count.dart';

class StockCountService {
  static final StockCountService _instance = StockCountService._internal();
  factory StockCountService() => _instance;
  StockCountService._internal();

  /// Physical counts entered but not yet submitted, keyed by item id.
  /// Lives on the service so the working set survives navigating away
  /// from the Stock Audit screen and back.
  final ValueNotifier<Map<int, int>> pendingCounts = ValueNotifier({});

  void setPendingCount(int itemId, int physicalQty) {
    pendingCounts.value = {...pendingCounts.value, itemId: physicalQty};
  }

  void removePendingCount(int itemId) {
    final next = {...pendingCounts.value}..remove(itemId);
    pendingCounts.value = next;
  }

  void clearPendingCounts() {
    pendingCounts.value = {};
  }

  /// Writes every pending count as one all-or-nothing transaction and
  /// returns the recorded rows. Pending counts are kept on failure so the
  /// owner can retry from the same working set.
  Future<List<StockCount>> submitPendingCounts() async {
    final pending = pendingCounts.value;
    if (pending.isEmpty) return [];

    final db = await DatabaseHelper().database;
    final countedAt = DateTime.now().millisecondsSinceEpoch;
    final recorded = <StockCount>[];

    await db.transaction((txn) async {
      for (final entry in pending.entries) {
        final rows = await txn.query(
          'items',
          columns: ['name', 'quantity'],
          where: 'id = ?',
          whereArgs: [entry.key],
        );
        if (rows.isEmpty) {
          throw StateError('Item ${entry.key} no longer exists.');
        }
        final systemQty = rows.first['quantity'] as int;
        final count = StockCount(
          itemId: entry.key,
          itemName: rows.first['name'] as String? ?? '',
          systemQty: systemQty,
          physicalQty: entry.value,
          variance: entry.value - systemQty,
          countedAt: countedAt,
        );
        await txn.insert('stock_counts', count.toMap());
        recorded.add(count);
      }
    });

    clearPendingCounts();
    recorded.sort((a, b) => a.variance.compareTo(b.variance));
    return recorded;
  }

  /// One row per counted item — its most recent count — worst shortage first.
  Future<List<StockCount>> getLatestCountPerItem() async {
    final db = await DatabaseHelper().database;
    final rows = await db.rawQuery(
      'SELECT sc.* FROM stock_counts sc '
      'INNER JOIN ('
      '  SELECT item_id, MAX(counted_at) AS max_counted_at '
      '  FROM stock_counts GROUP BY item_id'
      ') latest '
      'ON sc.item_id = latest.item_id '
      'AND sc.counted_at = latest.max_counted_at '
      'ORDER BY sc.variance ASC',
    );
    return rows.map((r) => StockCount.fromMap(r)).toList();
  }

  /// Full count history for one item, oldest first.
  Future<List<StockCount>> getCountHistoryForItem(int itemId) async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      'stock_counts',
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'counted_at ASC',
    );
    return rows.map((r) => StockCount.fromMap(r)).toList();
  }
}
