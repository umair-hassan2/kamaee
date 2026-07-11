import 'package:flutter_test/flutter_test.dart';
import 'package:kamaae/models/sale.dart';

void main() {
  group('Sale model', () {
    test('toMap / fromMap round-trips all fields', () {
      final sale = Sale(
        id: 7,
        customerId: 3,
        totalAmount: 500,
        paidAmount: 200,
        khataAmount: 300,
        paymentMethod: PaymentMethod.partial,
        status: SaleStatus.completed,
        timestamp: 1700000000000,
      );

      final map = sale.toMap();
      final restored = Sale.fromMap(map);

      expect(restored.id, 7);
      expect(restored.customerId, 3);
      expect(restored.totalAmount, 500);
      expect(restored.paidAmount, 200);
      expect(restored.khataAmount, 300);
      expect(restored.paymentMethod, PaymentMethod.partial);
      expect(restored.status, SaleStatus.completed);
      expect(restored.timestamp, 1700000000000);
    });

    test('toMap omits id when null', () {
      final sale = Sale(
        totalAmount: 100,
        paidAmount: 100,
        khataAmount: 0,
        paymentMethod: PaymentMethod.cash,
        status: SaleStatus.draft,
        timestamp: 0,
      );

      expect(sale.toMap().containsKey('id'), isFalse);
    });

    test('fromMap handles null customer_id', () {
      final map = {
        'id': 1,
        'customer_id': null,
        'total_amount': 100.0,
        'paid_amount': 100.0,
        'khata_amount': 0.0,
        'payment_method': 'cash',
        'status': 'completed',
        'timestamp': 0,
      };

      final sale = Sale.fromMap(map);
      expect(sale.customerId, isNull);
    });

    test('copyWith overrides only specified fields', () {
      final original = Sale(
        id: 1,
        totalAmount: 100,
        paidAmount: 100,
        khataAmount: 0,
        paymentMethod: PaymentMethod.cash,
        status: SaleStatus.draft,
        timestamp: 0,
      );

      final updated = original.copyWith(status: SaleStatus.completed, paidAmount: 80);

      expect(updated.id, 1);
      expect(updated.totalAmount, 100);
      expect(updated.status, SaleStatus.completed);
      expect(updated.paidAmount, 80);
    });
  });
}
