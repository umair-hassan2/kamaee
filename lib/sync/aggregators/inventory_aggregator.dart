import 'package:cloud_firestore/cloud_firestore.dart';
import '../../database_helper.dart';
import '../data_aggregator.dart';

class InventoryAggregator extends DataAggregator {
  final _db = DatabaseHelper();

  @override
  Future<void> aggregate(DocumentReference shopRef) async {
    final items = await _db.getAllItems();
    final since = DateTime.now().subtract(const Duration(days: 14));
    final salesPer14d = await _db.getItemSaleQuantitiesSince(since);

    final lowStockItems = <Map<String, dynamic>>[];
    final batch = FirebaseFirestore.instance.batch();
    final inventoryRef = shopRef.collection('inventory');

    for (final item in items) {
      final totalSold = salesPer14d[item.id] ?? 0;
      final avgDaily = totalSold / 14;
      final daysLeft = avgDaily > 0 ? item.quantity / avgDaily : 999.0;
      final isLow = item.quantity == 0 || daysLeft < 7;

      batch.set(inventoryRef.doc(item.id.toString()), {
        'id': item.id.toString(),
        'name': item.name,
        'current_stock': item.quantity,
        'purchase_price': item.purchasePrice,
        'selling_price': item.sellingPrice,
        'margin_pct': item.sellingPrice > 0
            ? _round2(
                (item.sellingPrice - item.purchasePrice) /
                    item.sellingPrice *
                    100,
              )
            : 0.0,
        'avg_daily_sales': _round2(avgDaily),
        'days_to_stockout': daysLeft >= 999 ? 999.0 : _round1(daysLeft),
        'is_low_stock': isLow,
        'synced_at': FieldValue.serverTimestamp(),
      });

      if (isLow) {
        lowStockItems.add({
          'name': item.name,
          'stock': item.quantity,
          'days_left': daysLeft >= 999 ? 999.0 : _round1(daysLeft),
        });
      }
    }

    batch.set(shopRef.collection('alerts').doc('low_stock'), {
      'items': lowStockItems,
      'count': lowStockItems.length,
      'generated_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  double _round1(double v) => double.parse(v.toStringAsFixed(1));
  double _round2(double v) => double.parse(v.toStringAsFixed(2));
}
