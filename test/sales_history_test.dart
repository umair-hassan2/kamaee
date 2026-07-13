import 'package:flutter_test/flutter_test.dart';
import 'package:kamaae/database_helper.dart';
import 'package:kamaae/models/customer.dart';
import 'package:kamaae/models/khata_entry.dart';
import 'package:kamaae/models/sale.dart';
import 'package:kamaae/services/cart_service.dart';
import 'package:kamaae/services/khata_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers/test_database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper db;
  late CartService cart;
  late KhataService khata;

  setUp(() async {
    await setUpTestDatabase();
    db = DatabaseHelper();
    cart = CartService();
    khata = KhataService();
  });

  tearDown(tearDownTestDatabase);

  // ─── getAllCompletedSales ──────────────────────────────────────────────────

  group('DatabaseHelper.getAllCompletedSales', () {
    test('returns empty list when no sales exist', () async {
      final sales = await db.getAllCompletedSales();
      expect(sales, isEmpty);
    });

    test('excludes draft sales', () async {
      final item = await insertTestItem(db, sellingPrice: 100);
      await cart.addItem(item, 1);
      // Draft created, but not completed
      final sales = await db.getAllCompletedSales();
      expect(sales, isEmpty);
    });

    test('returns completed sales in reverse-chronological order', () async {
      final itemA = await insertTestItem(db, barcode: 'A', name: 'A', sellingPrice: 50);
      final itemB = await insertTestItem(db, barcode: 'B', name: 'B', sellingPrice: 80);

      await cart.addItem(itemA, 1);
      final saleA = await cart.completeSale(
        paymentMethod: PaymentMethod.cash,
        paidAmount: 50,
      );

      await cart.addItem(itemB, 1);
      final saleB = await cart.completeSale(
        paymentMethod: PaymentMethod.cash,
        paidAmount: 80,
      );

      final sales = await db.getAllCompletedSales();
      expect(sales, hasLength(2));
      // Most recent first
      expect(sales.first.id, saleB.id);
      expect(sales.last.id, saleA.id);
    });

    test('returns sales with correct amounts', () async {
      final item = await insertTestItem(db, sellingPrice: 200);
      await cart.addItem(item, 2);
      await cart.completeSale(
        paymentMethod: PaymentMethod.cash,
        paidAmount: 400,
      );

      final sales = await db.getAllCompletedSales();
      expect(sales, hasLength(1));
      expect(sales.first.totalAmount, 400);
      expect(sales.first.paidAmount, 400);
      expect(sales.first.status, SaleStatus.completed);
    });
  });

  // ─── Rich khata description ───────────────────────────────────────────────

  group('CartService.completeSale — rich khata description', () {
    test('auto-creates khata entry with itemized description', () async {
      final customerId = await khata.addCustomer(Customer(
        name: 'Ahmed',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));

      final milk = await insertTestItem(db,
          barcode: 'M1', name: 'Doodh', sellingPrice: 100, quantity: 5);
      final bread = await insertTestItem(db,
          barcode: 'B1', name: 'Double Roti', sellingPrice: 50, quantity: 5);

      await cart.addItem(milk, 2);
      await cart.addItem(bread, 1);

      await cart.completeSale(
        paymentMethod: PaymentMethod.partial,
        paidAmount: 100,
        customerId: customerId,
      );

      final entries = await khata.getEntriesForCustomer(customerId);
      expect(entries, hasLength(1));
      final entry = entries.first;

      expect(entry.type, KhataEntryType.credit);
      // Khata = total 250 - paid 100 = 150
      expect(entry.amount, 150);

      // Description must mention both items, total, paid, and khata amounts
      expect(entry.note, contains('Doodh (2)'));
      expect(entry.note, contains('Double Roti (1)'));
      expect(entry.note, contains('Total: Rs.250'));
      expect(entry.note, contains('Paid: Rs.100'));
      expect(entry.note, contains('Khata: Rs.150'));
    });

    test('links khata entry to sale via saleId', () async {
      final customerId = await khata.addCustomer(Customer(
        name: 'Sara',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
      final item = await insertTestItem(db, sellingPrice: 300, quantity: 5);
      await cart.addItem(item, 1);

      final sale = await cart.completeSale(
        paymentMethod: PaymentMethod.khata,
        paidAmount: 0,
        customerId: customerId,
      );

      final entries = await khata.getEntriesForCustomer(customerId);
      expect(entries.first.saleId, sale.id);
    });

    test('does NOT create khata entry when fully paid with cash', () async {
      final item = await insertTestItem(db, sellingPrice: 100);
      await cart.addItem(item, 1);

      await cart.completeSale(
        paymentMethod: PaymentMethod.cash,
        paidAmount: 100,
      );

      // No customer → no entries possible, but also no crash
      final allEntries = await db.database
          .then((d) => d.query('khata_entries'));
      expect(allEntries, isEmpty);
    });

    test('partial payment creates correct khata and paid amounts', () async {
      final customerId = await khata.addCustomer(Customer(
        name: 'Bilal',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));
      final item = await insertTestItem(db, sellingPrice: 500, quantity: 5);
      await cart.addItem(item, 1);

      final sale = await cart.completeSale(
        paymentMethod: PaymentMethod.partial,
        paidAmount: 200,
        customerId: customerId,
      );

      expect(sale.paidAmount, 200);
      expect(sale.khataAmount, 300);

      final entries = await khata.getEntriesForCustomer(customerId);
      expect(entries.first.amount, 300);
      expect(entries.first.note, contains('Paid: Rs.200'));
      expect(entries.first.note, contains('Khata: Rs.300'));
    });
  });

  // ─── getTransactionsForSale ───────────────────────────────────────────────

  group('DatabaseHelper.getTransactionsForSale', () {
    test('returns line items for a completed sale', () async {
      final itemA = await insertTestItem(
          db, barcode: 'X1', name: 'ItemA', sellingPrice: 100, quantity: 5);
      final itemB = await insertTestItem(
          db, barcode: 'X2', name: 'ItemB', sellingPrice: 50, quantity: 5);

      await cart.addItem(itemA, 2);
      await cart.addItem(itemB, 3);

      final sale = await cart.completeSale(
        paymentMethod: PaymentMethod.cash,
        paidAmount: 350,
      );

      final lines = await db.getTransactionsForSale(sale.id!);
      expect(lines, hasLength(2));
      final names = lines.map((l) => l.itemName).toSet();
      expect(names, containsAll(['ItemA', 'ItemB']));
    });
  });
}
