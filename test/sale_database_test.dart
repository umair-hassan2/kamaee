import 'package:flutter_test/flutter_test.dart';
import 'package:kamaae/database_helper.dart';
import 'package:kamaae/models/item.dart';
import 'package:kamaae/models/sale.dart';
import 'package:kamaae/models/transaction.dart';

import 'helpers/test_database.dart';

SaleTransaction buildTx(Item item, {int? saleId, int quantity = 1}) {
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

void main() {
  late DatabaseHelper db;

  setUp(() async {
    await setUpTestDatabase();
    db = DatabaseHelper();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('DatabaseHelper — sales', () {
    test('insertSale returns an id and getDraftSale finds it', () async {
      final id = await db.insertSale(Sale(
        totalAmount: 0,
        paidAmount: 0,
        khataAmount: 0,
        paymentMethod: PaymentMethod.cash,
        status: SaleStatus.draft,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));

      expect(id, greaterThan(0));

      final draft = await db.getDraftSale();
      expect(draft, isNotNull);
      expect(draft!.id, id);
      expect(draft.status, SaleStatus.draft);
    });

    test('getDraftSale returns null when no draft exists', () async {
      final draft = await db.getDraftSale();
      expect(draft, isNull);
    });

    test('updateSale persists changes', () async {
      await db.insertSale(Sale(
        totalAmount: 0,
        paidAmount: 0,
        khataAmount: 0,
        paymentMethod: PaymentMethod.cash,
        status: SaleStatus.draft,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));

      final draft = (await db.getDraftSale())!;
      await db.updateSale(draft.copyWith(
        totalAmount: 250,
        status: SaleStatus.completed,
      ));

      final completed = await db.getCompletedSalesBetween(
        DateTime(2000),
        DateTime(2100),
      );
      expect(completed, hasLength(1));
      expect(completed.first.totalAmount, 250);
      expect(completed.first.status, SaleStatus.completed);
    });

    test('deleteSale removes the record', () async {
      final id = await db.insertSale(Sale(
        totalAmount: 0,
        paidAmount: 0,
        khataAmount: 0,
        paymentMethod: PaymentMethod.cash,
        status: SaleStatus.draft,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));

      await db.deleteSale(id);
      final draft = await db.getDraftSale();
      expect(draft, isNull);
    });

    test('getSalesByCustomer returns only that customer\'s completed sales', () async {
      Future<void> insertCompleted(int customerId, double amount) async {
        final id = await db.insertSale(Sale(
          customerId: customerId,
          totalAmount: amount,
          paidAmount: amount,
          khataAmount: 0,
          paymentMethod: PaymentMethod.cash,
          status: SaleStatus.draft,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ));
        await db.updateSale(Sale(
          id: id,
          customerId: customerId,
          totalAmount: amount,
          paidAmount: amount,
          khataAmount: 0,
          paymentMethod: PaymentMethod.cash,
          status: SaleStatus.completed,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ));
      }

      await insertCompleted(1, 100);
      await insertCompleted(1, 150);
      await insertCompleted(2, 200);

      final sales1 = await db.getSalesByCustomer(1);
      final sales2 = await db.getSalesByCustomer(2);

      expect(sales1, hasLength(2));
      expect(sales2, hasLength(1));
      expect(sales2.first.totalAmount, 200);
    });

    test('getSalesByCustomer excludes draft sales', () async {
      await db.insertSale(Sale(
        customerId: 1,
        totalAmount: 50,
        paidAmount: 0,
        khataAmount: 0,
        paymentMethod: PaymentMethod.cash,
        status: SaleStatus.draft,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));

      final sales = await db.getSalesByCustomer(1);
      expect(sales, isEmpty);
    });

    test('getTransactionsForSale returns only that sale\'s line items', () async {
      final item = await insertTestItem(db, barcode: 'A001');
      final item2 = await insertTestItem(db, barcode: 'A002', name: 'Item 2');

      final saleId = await db.insertSale(Sale(
        totalAmount: 0,
        paidAmount: 0,
        khataAmount: 0,
        paymentMethod: PaymentMethod.cash,
        status: SaleStatus.draft,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));

      await db.insertTransaction(buildTx(item, saleId: saleId));
      await db.insertTransaction(buildTx(item2)); // unlinked

      final lines = await db.getTransactionsForSale(saleId);
      expect(lines, hasLength(1));
      expect(lines.first.itemName, item.name);
    });

    test('deleteTransactionsForSale removes only that sale\'s items', () async {
      final item = await insertTestItem(db, barcode: 'B001');
      final item2 = await insertTestItem(db, barcode: 'B002', name: 'Item 2');

      final saleId = await db.insertSale(Sale(
        totalAmount: 0,
        paidAmount: 0,
        khataAmount: 0,
        paymentMethod: PaymentMethod.cash,
        status: SaleStatus.draft,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));

      await db.insertTransaction(buildTx(item, saleId: saleId));
      await db.insertTransaction(buildTx(item2)); // unlinked

      await db.deleteTransactionsForSale(saleId);

      expect(await db.getTransactionsForSale(saleId), isEmpty);

      final all = await db.getTransactionsBetween(DateTime(2000), DateTime(2100));
      expect(all, hasLength(1)); // unlinked one survives
    });
  });
}
