import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';
import '../models/item.dart';

class InventoryService {
  final DatabaseHelper _db = DatabaseHelper();

  Future<Item> sellItem(Item item, int quantity) async {
    if (quantity <= 0) {
      throw ArgumentError('Quantity must be greater than 0');
    }
    if (quantity > item.quantity) {
      throw StateError('Not enough stock');
    }

    final updated = item.copyWith(quantity: item.quantity - quantity);
    await _db.updateItem(updated);

    final prefs = await SharedPreferences.getInstance();
    final balance = prefs.getDouble('balance') ?? 0.0;
    await prefs.setDouble('balance', balance + (item.sellingPrice * quantity));

    return updated;
  }

  Future<Item> restockItem(Item item, int quantity) async {
    if (quantity <= 0) {
      throw ArgumentError('Quantity must be greater than 0');
    }

    final updated = item.copyWith(quantity: item.quantity + quantity);
    await _db.updateItem(updated);
    return updated;
  }
}
