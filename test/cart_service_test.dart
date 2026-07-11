import 'package:flutter_test/flutter_test.dart';
import 'package:kamaae/database_helper.dart';
import 'package:kamaae/models/customer.dart';
import 'package:kamaae/models/khata_entry.dart';
import 'package:kamaae/models/sale.dart';
import 'package:kamaae/services/cart_service.dart';
import 'package:kamaae/services/khata_service.dart';

import 'helpers/test_database.dart';

Customer _makeCustomer(String name) => Customer(
      name: name,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

void main() {
  late CartService cart;
  late DatabaseHelper db;

  setUp(() async {
    await setUpTestDatabase();
    db = DatabaseHelper();
    cart = CartService();
    await cart.init(); // hydrate badge from fresh (empty) DB
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('CartService — cart lifecycle', () {
    test('getOrCreateDraft creates a draft sale on first call', () async {
      final draft = await cart.getOrCreateDraft();
      expect(draft.id, isNotNull);
      expect(draft.status, SaleStatus.draft);
    });

    test('getOrCreateDraft returns the same draft on repeated calls', () async {
      final a = await cart.getOrCreateDraft();
      final b = await cart.getOrCreateDraft();
      expect(a.id, b.id);
    });

    test('addItem creates a line in the draft', () async {
      final item = await insertTestItem(db, sellingPrice: 100);

      await cart.addItem(item, 2);

      final lines = await cart.getCartItems();
      expect(lines, hasLength(1));
      expect(lines.first.quantity, 2);
      expect(lines.first.revenue, 200);
    });

    test('addItem merges quantity when same item added twice', () async {
      final item = await insertTestItem(db, sellingPrice: 50);

      await cart.addItem(item, 1);
      await cart.addItem(item, 3);

      final lines = await cart.getCartItems();
      expect(lines, hasLength(1));
      expect(lines.first.quantity, 4);
      expect(lines.first.revenue, 200);
    });

    test('addItem keeps separate lines for different items', () async {
      final a = await insertTestItem(db, barcode: 'X1', name: 'A');
      final b = await insertTestItem(db, barcode: 'X2', name: 'B');

      await cart.addItem(a, 1);
      await cart.addItem(b, 2);

      expect(await cart.getCartItems(), hasLength(2));
    });

    test('cartCount reflects total units in cart', () async {
      final item = await insertTestItem(db);
      await cart.addItem(item, 5);
      expect(cart.cartCount.value, 5);
    });

    test('updateItemQty changes quantity and recalculates revenue', () async {
      final item = await insertTestItem(db, sellingPrice: 100);
      await cart.addItem(item, 2);

      final line = (await cart.getCartItems()).first;
      await cart.updateItemQty(line.id!, 5);

      final updated = (await cart.getCartItems()).first;
      expect(updated.quantity, 5);
      expect(updated.revenue, 500);
    });

    test('updateItemQty with 0 removes the line', () async {
      final item = await insertTestItem(db);
      await cart.addItem(item, 2);

      final line = (await cart.getCartItems()).first;
      await cart.updateItemQty(line.id!, 0);

      expect(await cart.getCartItems(), isEmpty);
      expect(cart.cartCount.value, 0);
    });

    test('removeItem deletes the line', () async {
      final item = await insertTestItem(db);
      await cart.addItem(item, 3);

      final line = (await cart.getCartItems()).first;
      await cart.removeItem(line.id!);

      expect(await cart.getCartItems(), isEmpty);
    });

    test('clearCart deletes draft sale and all its items', () async {
      final item = await insertTestItem(db);
      await cart.addItem(item, 2);

      await cart.clearCart();

      expect(await cart.getCartItems(), isEmpty);
      expect(await db.getDraftSale(), isNull);
      expect(cart.cartCount.value, 0);
    });
  });

  group('CartService — completeSale (cash)', () {
    test('deducts stock, marks sale completed, zeroes cart', () async {
      final item = await insertTestItem(db, quantity: 10, sellingPrice: 100);
      await cart.addItem(item, 3);

      final sale = await cart.completeSale(
        paymentMethod: PaymentMethod.cash,
        paidAmount: 300,
      );

      expect(sale.status, SaleStatus.completed);
      expect(sale.totalAmount, 300);
      expect(sale.paidAmount, 300);
      expect(sale.khataAmount, 0);

      final updated = await db.getItemById(item.id!);
      expect(updated!.quantity, 7);

      expect(await db.getDraftSale(), isNull);
      expect(cart.cartCount.value, 0);
    });

    test('records transactions linked to the sale', () async {
      final item = await insertTestItem(db, sellingPrice: 50);
      await cart.addItem(item, 2);

      final sale = await cart.completeSale(
        paymentMethod: PaymentMethod.cash,
        paidAmount: 100,
      );

      final txs = await db.getTransactionsForSale(sale.id!);
      expect(txs, hasLength(1));
      expect(txs.first.revenue, 100);
      expect(txs.first.saleId, sale.id);
    });

    test('throws StateError when cart is empty', () async {
      await cart.getOrCreateDraft();

      expect(
        () => cart.completeSale(paymentMethod: PaymentMethod.cash, paidAmount: 0),
        throwsA(isA<StateError>()),
      );
    });

    test('throws StateError when stock is insufficient at checkout', () async {
      final item = await insertTestItem(db, quantity: 1);
      await cart.addItem(item, 1);

      // Simulate concurrent stock depletion
      await db.updateItem(item.copyWith(quantity: 0));

      expect(
        () => cart.completeSale(
          paymentMethod: PaymentMethod.cash,
          paidAmount: item.sellingPrice,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('CartService — completeSale (khata)', () {
    test('full khata sale creates KhataEntry for the full amount', () async {
      final khataService = KhataService();
      final customerId =
          await khataService.addCustomer(_makeCustomer('Ali'));

      final item = await insertTestItem(db, sellingPrice: 200);
      await cart.addItem(item, 1);

      final sale = await cart.completeSale(
        paymentMethod: PaymentMethod.khata,
        paidAmount: 0,
        customerId: customerId,
      );

      expect(sale.khataAmount, 200);
      expect(sale.paymentMethod, PaymentMethod.khata);

      final entries = await khataService.getEntriesForCustomer(customerId);
      expect(entries, hasLength(1));
      expect(entries.first.type, KhataEntryType.credit);
      expect(entries.first.amount, 200);
      expect(entries.first.saleId, sale.id);
    });

    test('partial payment creates KhataEntry for the remainder', () async {
      final khataService = KhataService();
      final customerId =
          await khataService.addCustomer(_makeCustomer('Bilal'));

      final item = await insertTestItem(db, sellingPrice: 500);
      await cart.addItem(item, 1);

      final sale = await cart.completeSale(
        paymentMethod: PaymentMethod.partial,
        paidAmount: 200,
        customerId: customerId,
      );

      expect(sale.paidAmount, 200);
      expect(sale.khataAmount, 300);

      final entries = await khataService.getEntriesForCustomer(customerId);
      expect(entries, hasLength(1));
      expect(entries.first.amount, 300);
    });

    test('cash sale does NOT create KhataEntry even with a customerId', () async {
      final khataService = KhataService();
      final customerId =
          await khataService.addCustomer(_makeCustomer('Zain'));

      final item = await insertTestItem(db, sellingPrice: 100);
      await cart.addItem(item, 1);

      await cart.completeSale(
        paymentMethod: PaymentMethod.cash,
        paidAmount: 100,
        customerId: customerId,
      );

      expect(
        await khataService.getEntriesForCustomer(customerId),
        isEmpty,
      );
    });

    test('khata sale without customerId does NOT create KhataEntry', () async {
      final item = await insertTestItem(db, sellingPrice: 150);
      await cart.addItem(item, 1);

      final sale = await cart.completeSale(
        paymentMethod: PaymentMethod.khata,
        paidAmount: 0,
        customerId: null,
      );

      expect(sale.khataAmount, 150);

      final khataRows =
          await (await db.database).query('khata_entries');
      expect(khataRows, isEmpty);
    });
  });

  group('CartService — draft total recalculation', () {
    test('total updates when item is added', () async {
      final item = await insertTestItem(db, sellingPrice: 80);
      await cart.addItem(item, 3);

      final draft = await db.getDraftSale();
      expect(draft!.totalAmount, 240);
    });

    test('total updates when qty changes', () async {
      final item = await insertTestItem(db, sellingPrice: 50);
      await cart.addItem(item, 2);

      final line = (await cart.getCartItems()).first;
      await cart.updateItemQty(line.id!, 4);

      final draft = await db.getDraftSale();
      expect(draft!.totalAmount, 200);
    });

    test('total updates when item is removed', () async {
      final a = await insertTestItem(
          db, barcode: 'T1', name: 'A', sellingPrice: 100);
      final b = await insertTestItem(
          db, barcode: 'T2', name: 'B', sellingPrice: 50);
      await cart.addItem(a, 1);
      await cart.addItem(b, 2);

      final lineB =
          (await cart.getCartItems()).firstWhere((l) => l.itemName == 'B');
      await cart.removeItem(lineB.id!);

      final draft = await db.getDraftSale();
      expect(draft!.totalAmount, 100);
    });
  });
}
