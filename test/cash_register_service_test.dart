import 'package:flutter_test/flutter_test.dart';
import 'package:kamaae/database_helper.dart';
import 'package:kamaae/models/cash_session.dart';
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

  test('closeSession computes expected cash from sales', () async {
    final item = await insertTestItem(db, sellingPrice: 100);
    final session = await service.openSession(2000);

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
      timestamp: DateTime.fromMillisecondsSinceEpoch(session.openedAt + 1000),
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
