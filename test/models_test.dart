import 'package:flutter_test/flutter_test.dart';
import 'package:kamaae/models/finance_models.dart';
import 'package:kamaae/models/item.dart';
import 'package:kamaae/models/transaction.dart';

void main() {
  group('Item', () {
    test('serializes to and from map', () {
      final item = Item(
        id: 1,
        barcode: 'ABC',
        name: 'Soap',
        purchasePrice: 40,
        sellingPrice: 60,
        quantity: 5,
      );

      final restored = Item.fromMap(item.toMap());

      expect(restored.id, 1);
      expect(restored.barcode, 'ABC');
      expect(restored.name, 'Soap');
      expect(restored.purchasePrice, 40);
      expect(restored.sellingPrice, 60);
      expect(restored.quantity, 5);
    });

    test('copyWith updates selected fields', () {
      final item = Item(
        barcode: 'ABC',
        name: 'Soap',
        purchasePrice: 40,
        sellingPrice: 60,
        quantity: 5,
      );

      final updated = item.copyWith(quantity: 3);

      expect(updated.quantity, 3);
      expect(updated.name, 'Soap');
    });
  });

  group('SaleTransaction', () {
    test('serializes to and from map', () {
      final tx = SaleTransaction(
        id: 2,
        itemId: 1,
        itemName: 'Soap',
        type: TransactionType.sell,
        quantity: 2,
        unitCost: 40,
        unitPrice: 60,
        revenue: 120,
        cost: 80,
        profit: 40,
        timestamp: DateTime(2026, 7, 7, 12),
      );

      final restored = SaleTransaction.fromMap(tx.toMap());

      expect(restored.id, 2);
      expect(restored.type, TransactionType.sell);
      expect(restored.revenue, 120);
      expect(restored.profit, 40);
    });
  });

  group('PeriodSummary', () {
    test('marginPercent is zero when revenue is zero', () {
      const summary = PeriodSummary();
      expect(summary.marginPercent, 0);
    });

    test('marginPercent calculates correctly', () {
      const summary = PeriodSummary(revenue: 200, profit: 50);
      expect(summary.marginPercent, 25);
    });
  });
}
