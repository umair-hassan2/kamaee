import 'package:flutter/foundation.dart';
import '../database_helper.dart';
import '../models/khata_entry.dart';
import '../services/khata_service.dart';
import '../models/item.dart';
import '../models/sale.dart';
import '../models/transaction.dart';
import 'notification_service.dart';
import 'settings_service.dart';

class CartService {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final _db = DatabaseHelper();

  /// Reactive cart item count (total units) for badges.
  final ValueNotifier<int> cartCount = ValueNotifier(0);

  // ─── Draft Sale ──────────────────────────────────────────────────────────────

  /// Returns the active draft Sale, creating one if none exists.
  Future<Sale> getOrCreateDraft() async {
    final existing = await _db.getDraftSale();
    if (existing != null) return existing;

    final id = await _db.insertSale(Sale(
      totalAmount: 0,
      paidAmount: 0,
      khataAmount: 0,
      paymentMethod: PaymentMethod.cash,
      status: SaleStatus.draft,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
    return (await _db.getDraftSale())!;
  }

  Future<List<SaleTransaction>> getCartItems() async {
    final draft = await _db.getDraftSale();
    if (draft == null || draft.id == null) return [];
    return _db.getTransactionsForSale(draft.id!);
  }

  /// Adds an item to the cart. If the item is already in the draft,
  /// increments the quantity instead of creating a duplicate line.
  Future<void> addItem(Item item, int quantity) async {
    if (quantity <= 0) return;
    final draft = await getOrCreateDraft();
    final existing = await _db.getTransactionsForSale(draft.id!);

    // Check if item already in cart
    final existing_line = existing.where((t) => t.itemId == item.id).toList();

    if (existing_line.isNotEmpty) {
      // Update quantity of existing line
      final line = existing_line.first;
      final newQty = line.quantity + quantity;
      // Delete old line and re-insert with merged quantity
      final db = await _db.database;
      await db.delete('transactions', where: 'id = ?', whereArgs: [line.id]);
      await _db.insertTransaction(_buildTransaction(item, newQty, draft.id!));
    } else {
      await _db.insertTransaction(_buildTransaction(item, quantity, draft.id!));
    }

    await _recalculateDraftTotal(draft.id!);
    await _refreshCount();
  }

  Future<void> updateItemQty(int transactionId, int newQty) async {
    if (newQty <= 0) {
      await removeItem(transactionId);
      return;
    }
    final draft = await _db.getDraftSale();
    if (draft == null) return;

    final db = await _db.database;
    final rows = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [transactionId],
    );
    if (rows.isEmpty) return;

    final line = SaleTransaction.fromMap(rows.first);
    final updated = SaleTransaction(
      id: line.id,
      itemId: line.itemId,
      itemName: line.itemName,
      type: line.type,
      quantity: newQty,
      unitCost: line.unitCost,
      unitPrice: line.unitPrice,
      revenue: line.unitPrice * newQty,
      cost: line.unitCost * newQty,
      profit: (line.unitPrice - line.unitCost) * newQty,
      timestamp: line.timestamp,
      saleId: line.saleId,
    );
    await db.update(
      'transactions',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [transactionId],
    );
    await _recalculateDraftTotal(draft.id!);
    await _refreshCount();
  }

  Future<void> removeItem(int transactionId) async {
    final draft = await _db.getDraftSale();
    if (draft == null) return;
    final db = await _db.database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [transactionId]);
    await _recalculateDraftTotal(draft.id!);
    await _refreshCount();
  }

  /// Clears the cart entirely (deletes draft sale + its line items).
  Future<void> clearCart() async {
    final draft = await _db.getDraftSale();
    if (draft == null) return;
    await _db.deleteTransactionsForSale(draft.id!);
    await _db.deleteSale(draft.id!);
    cartCount.value = 0;
  }

  // ─── Checkout ─────────────────────────────────────────────────────────────────

  /// Completes the sale:
  /// 1. Deducts stock for each line item
  /// 2. Updates each transaction's timestamp to now
  /// 3. Marks the Sale as completed
  /// Returns the completed Sale.
  Future<Sale> completeSale({
    required PaymentMethod paymentMethod,
    required double paidAmount,
    int? customerId,
  }) async {
    final draft = await _db.getDraftSale();
    if (draft == null) throw StateError('No active cart');
    if (draft.id == null) throw StateError('Draft sale has no ID');

    final lines = await _db.getTransactionsForSale(draft.id!);
    if (lines.isEmpty) throw StateError('Cart is empty');

    final now = DateTime.now();
    final db = await _db.database;

    // Deduct stock and update transaction timestamps in a transaction
    await db.transaction((txn) async {
      for (final line in lines) {
        // Get current stock
        final itemRows = await txn.query(
          'items',
          where: 'id = ?',
          whereArgs: [line.itemId],
        );
        if (itemRows.isEmpty) continue;
        final currentQty = itemRows.first['quantity'] as int;
        if (currentQty < line.quantity) {
          throw StateError(
            '"${line.itemName}" has only $currentQty in stock but cart has ${line.quantity}',
          );
        }
        // Deduct stock
        await txn.update(
          'items',
          {'quantity': currentQty - line.quantity},
          where: 'id = ?',
          whereArgs: [line.itemId],
        );
        // Stamp the transaction with sale timestamp
        await txn.update(
          'transactions',
          {'timestamp': now.millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [line.id],
        );
      }
    });

    // Low stock notifications (fire and forget)
    for (final line in lines) {
      final item = await _db.getItemById(line.itemId);
      if (item != null) {
        final threshold = SettingsService().lowStockThreshold;
        if (item.quantity <= threshold) {
          NotificationService().showLowStockAlert(item.name, item.quantity);
        }
      }
    }

    final total = draft.totalAmount;
    final khata = total - paidAmount;
    final khataAmount = khata < 0 ? 0.0 : khata;
    final completed = draft.copyWith(
      customerId: customerId,
      paidAmount: paidAmount,
      khataAmount: khataAmount,
      paymentMethod: paymentMethod,
      status: SaleStatus.completed,
      timestamp: now.millisecondsSinceEpoch,
    );
    await _db.updateSale(completed);

    // Auto-create KhataEntry if credit is involved
    if (khataAmount > 0 && customerId != null) {
      final khataService = KhataService();
      await khataService.addEntry(KhataEntry(
        customerId: customerId,
        type: KhataEntryType.credit,
        amount: khataAmount,
        note: 'Sale #${completed.id}',
        timestamp: now.millisecondsSinceEpoch,
        saleId: completed.id,
      ));
    }

    cartCount.value = 0;
    return completed;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  SaleTransaction _buildTransaction(Item item, int quantity, int saleId) {
    return SaleTransaction(
      itemId: item.id!,
      itemName: item.name,
      type: TransactionType.sell,
      quantity: quantity,
      unitCost: item.purchasePrice,
      unitPrice: item.sellingPrice,
      revenue: item.sellingPrice * quantity,
      cost: item.purchasePrice * quantity,
      profit: (item.sellingPrice - item.purchasePrice) * quantity,
      timestamp: DateTime.now(),
      saleId: saleId,
    );
  }

  Future<void> _recalculateDraftTotal(int saleId) async {
    final lines = await _db.getTransactionsForSale(saleId);
    final total = lines.fold(0.0, (sum, l) => sum + l.revenue);
    final draft = await _db.getDraftSale();
    if (draft != null) {
      await _db.updateSale(draft.copyWith(totalAmount: total));
    }
  }

  Future<void> _refreshCount() async {
    final items = await getCartItems();
    cartCount.value = items.fold(0, (sum, t) => sum + t.quantity);
  }

  /// Call on app start to hydrate the badge from any persisted draft.
  Future<void> init() async {
    await _refreshCount();
  }
}
