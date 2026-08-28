import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/shop_service.dart';
import 'aggregators/inventory_aggregator.dart';
import 'aggregators/khata_aggregator.dart';
import 'aggregators/sales_aggregator.dart';
import 'data_aggregator.dart';

enum SyncTrigger { sale, restock, khata }

class SyncRegistry {
  SyncRegistry._();

  static final Map<SyncTrigger, List<DataAggregator>> _map = {
    SyncTrigger.sale: [SalesAggregator(), InventoryAggregator()],
    SyncTrigger.restock: [InventoryAggregator()],
    SyncTrigger.khata: [KhataAggregator()],
  };

  /// Fire-and-forget. Resolves shopRef once, then runs all registered
  /// aggregators for [trigger] in parallel. Silent-fails per aggregator.
  static void trigger(SyncTrigger trigger) {
    unawaited(_dispatch(trigger).catchError((_) {}));
  }

  static Future<void> _dispatch(SyncTrigger trigger) async {
    final shopId = await ShopService().shopId;
    final shopRef =
        FirebaseFirestore.instance.collection('shops').doc(shopId);

    await Future.wait(
      (_map[trigger] ?? []).map(
        (aggregator) => aggregator
            .aggregate(shopRef)
            .catchError((e, st) => null),
      ),
    );
  }
}
