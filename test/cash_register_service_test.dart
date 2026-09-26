import 'package:flutter_test/flutter_test.dart';
import 'package:kamaae/database_helper.dart';
import 'package:kamaae/models/cash_session.dart';
import 'package:kamaae/models/sale.dart';
import 'package:kamaae/models/transaction.dart';
import 'package:kamaae/services/cash_register_service.dart';

import 'helpers/test_database.dart';

void main() {
  late CashRegisterService service;
  late DatabaseHelper db;

  setUp(() async {
    await setUpTestDatabase();
    service = CashRegisterService();
    db = DatabaseHelper();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('getActiveSession returns null when no session exists', () async {
    final session = await service.getActiveSession();
    expect(session, isNull);
  });

  test('openSession creates an active session', () async {
    final session = await service.openSession(5000);
    expect(session.id, greaterThan(0));
    expect(session.openingCash, 5000);
    expect(session.isOpen, isTrue);

    final active = await service.getActiveSession();
    expect(active, isNotNull);
    expect(active!.openingCash, 5000);
  });

  test('openSession throws if a session is already open', () async {
    await service.openSession(5000);
    expect(() => service.openSession(1000), throwsStateError);
  });

  test('closeSession counts direct-sell revenue as cash', () async {
    final item = await insertTestItem(db, sellingPrice: 100);
    final session = await backdateSession(db, await service.openSession(2000));

    await insertTestTransaction(
      db,
      item: item,
      type: TransactionType.sell,
      quantity: 3,
      timestamp: DateTime.fromMillisecondsSinceEpoch(session.openedAt + 1000),
    );

    final closed = await service.closeSession(2300);
    // expected = 2000 (opening) + 300 (3 × 100) = 2300
    expect(closed.expectedCash, 2300);
    expect(closed.closingCash, 2300);
    expect(closed.discrepancy, 0);
    expect(closed.isOpen, isFalse);
  });

  test('closeSession excludes khata revenue from expected cash', () async {
    final session = await backdateSession(db, await service.openSession(1000));

    await insertTestSale(
      db,
      totalAmount: 500,
      paidAmount: 0,
      paymentMethod: PaymentMethod.khata,
      timestamp: DateTime.fromMillisecondsSinceEpoch(session.openedAt),
    );

    final closed = await service.closeSession(1000);
    // Credit sale never reaches the drawer — expected stays at opening cash.
    expect(closed.expectedCash, 1000);
    expect(closed.discrepancy, 0);
  });

  test('closeSession counts only the paid portion of a partial sale', () async {
    final session = await backdateSession(db, await service.openSession(1000));

    await insertTestSale(
      db,
      totalAmount: 500,
      paidAmount: 200,
      paymentMethod: PaymentMethod.partial,
      timestamp: DateTime.fromMillisecondsSinceEpoch(session.openedAt),
    );

    final closed = await service.closeSession(1200);
    expect(closed.expectedCash, 1200);
    expect(closed.discrepancy, 0);
  });

  test('closeSession counts a fully paid checkout sale', () async {
    final session = await backdateSession(db, await service.openSession(1000));

    await insertTestSale(
      db,
      totalAmount: 750,
      paidAmount: 750,
      timestamp: DateTime.fromMillisecondsSinceEpoch(session.openedAt),
    );

    final closed = await service.closeSession(1750);
    expect(closed.expectedCash, 1750);
  });

  test('closeSession sums checkout and direct-sell cash together', () async {
    final item = await insertTestItem(db, sellingPrice: 100);
    final session = await backdateSession(db, await service.openSession(1000));
    final within =
        DateTime.fromMillisecondsSinceEpoch(session.openedAt + 1000);

    await insertTestSale(
      db,
      totalAmount: 500,
      paidAmount: 300,
      paymentMethod: PaymentMethod.partial,
      timestamp: within,
    );
    await insertTestSale(
      db,
      totalAmount: 400,
      paidAmount: 0,
      paymentMethod: PaymentMethod.khata,
      timestamp: within,
    );
    await insertTestTransaction(
      db,
      item: item,
      type: TransactionType.sell,
      quantity: 2,
      timestamp: within,
    );

    final closed = await service.closeSession(1500);
    // 1000 opening + 300 paid + 200 direct sells; khata excluded.
    expect(closed.expectedCash, 1500);
    expect(closed.discrepancy, 0);
  });

  test('closeSession excludes draft sales from expected cash', () async {
    final session = await backdateSession(db, await service.openSession(1000));

    await insertTestSale(
      db,
      totalAmount: 500,
      paidAmount: 500,
      status: SaleStatus.draft,
      timestamp: DateTime.fromMillisecondsSinceEpoch(session.openedAt),
    );

    final closed = await service.closeSession(1000);
    expect(closed.expectedCash, 1000);
  });

  test('closeSession excludes sales from before the session opened', () async {
    final session = await backdateSession(db, await service.openSession(1000));

    await insertTestSale(
      db,
      totalAmount: 500,
      paidAmount: 500,
      timestamp: DateTime.fromMillisecondsSinceEpoch(session.openedAt - 1),
    );

    final closed = await service.closeSession(1000);
    expect(closed.expectedCash, 1000);
  });

  test('closeSession includes a sale timestamped exactly at openedAt', () async {
    final session = await backdateSession(db, await service.openSession(1000));

    await insertTestSale(
      db,
      totalAmount: 500,
      paidAmount: 500,
      timestamp: DateTime.fromMillisecondsSinceEpoch(session.openedAt),
    );

    final closed = await service.closeSession(1500);
    expect(closed.expectedCash, 1500);
  });

  test('closeSession excludes a sale timestamped after the close', () async {
    await backdateSession(db, await service.openSession(1000));

    await insertTestSale(
      db,
      totalAmount: 500,
      paidAmount: 500,
      timestamp: DateTime.now().add(const Duration(minutes: 5)),
    );

    final closed = await service.closeSession(1000);
    // Belongs to the next session, not this one.
    expect(closed.expectedCash, 1000);
  });

  test('getExpectedCashForSession matches the close-session figure', () async {
    final session = await backdateSession(db, await service.openSession(1000));

    await insertTestSale(
      db,
      totalAmount: 500,
      paidAmount: 300,
      paymentMethod: PaymentMethod.partial,
      timestamp: DateTime.fromMillisecondsSinceEpoch(session.openedAt),
    );

    final live = await service.getExpectedCashForSession(session);
    final closed = await service.closeSession(1300);

    expect(live, 1300);
    expect(closed.expectedCash, live);
  });

  test('closeSession records discrepancy when cash count differs', () async {
    await service.openSession(1000);

    final closed = await service.closeSession(900);
    // expected = 1000 + 0 sales = 1000; counted 900 → -100 short
    expect(closed.discrepancy, closeTo(-100, 0.01));
  });

  test('closeSession throws if no active session', () async {
    expect(() => service.closeSession(500), throwsStateError);
  });

  test('getActiveSession returns null after session is closed', () async {
    await service.openSession(5000);
    await service.closeSession(5000);
    final active = await service.getActiveSession();
    expect(active, isNull);
  });

  test('getSessionHistory returns closed sessions only', () async {
    await service.openSession(1000);
    await service.closeSession(1000);
    await service.openSession(2000);
    await service.closeSession(2000);

    final history = await service.getSessionHistory();
    expect(history.length, 2);
    expect(history.every((s) => !s.isOpen), isTrue);
  });

  test('getSalesCountSince counts only sells after openedAt', () async {
    final item = await insertTestItem(db);
    final session = await service.openSession(0);

    await insertTestTransaction(
      db,
      item: item,
      type: TransactionType.sell,
      quantity: 1,
      timestamp: DateTime.fromMillisecondsSinceEpoch(session.openedAt),
    );
    await insertTestTransaction(
      db,
      item: item,
      type: TransactionType.restock,
      quantity: 10,
      timestamp: DateTime.fromMillisecondsSinceEpoch(session.openedAt + 2000),
    );

    final count = await service.getSalesCountSince(session.openedAt);
    expect(count, 1);
  });

  test('CashSession.fromMap round-trips through toMap', () {
    const session = CashSession(
      id: 1,
      openingCash: 5000,
      closingCash: 5200,
      expectedCash: 5100,
      discrepancy: 100,
      openedAt: 1000000,
      closedAt: 2000000,
      notes: 'End of day',
    );
    final restored = CashSession.fromMap(session.toMap());
    expect(restored.id, session.id);
    expect(restored.openingCash, session.openingCash);
    expect(restored.closingCash, session.closingCash);
    expect(restored.expectedCash, session.expectedCash);
    expect(restored.discrepancy, session.discrepancy);
    expect(restored.openedAt, session.openedAt);
    expect(restored.closedAt, session.closedAt);
    expect(restored.notes, session.notes);
  });
}
