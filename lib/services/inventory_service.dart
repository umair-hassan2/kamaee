import 'dart:async';
import '../database_helper.dart';
import '../models/item.dart';
import 'finance_service.dart';
import '../sync/sync_registry.dart';
import 'notification_service.dart';
import 'settings_service.dart';

class InventoryService {
  final DatabaseHelper _db = DatabaseHelper();
  final InventoryFinanceLogger _finance = InventoryFinanceLogger();

  Future<Item> sellItem(Item item, int quantity) async {
    if (quantity <= 0) {
      throw ArgumentError('Quantity must be greater than 0');
    }
    if (quantity > item.quantity) {
      throw StateError('Not enough stock');
    }

    final updated = item.copyWith(quantity: item.quantity - quantity);
    await _db.updateItem(updated);
    await _finance.logSell(item, quantity);

    final threshold = SettingsService().lowStockThreshold;
    if (updated.quantity <= threshold) {
      unawaited(
        NotificationService().showLowStockAlert(item.name, updated.quantity),
      );
    }

    return updated;
  }

  Future<Item> restockItem(Item item, int quantity) async {
    if (quantity <= 0) {
      throw ArgumentError('Quantity must be greater than 0');
    }

    final updated = item.copyWith(quantity: item.quantity + quantity);
    await _db.updateItem(updated);
    await _finance.logRestock(item, quantity);
    SyncRegistry.trigger(SyncTrigger.restock);
    return updated;
  }
}
