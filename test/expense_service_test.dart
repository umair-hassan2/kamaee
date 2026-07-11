import 'package:flutter_test/flutter_test.dart';
import 'package:kamaae/database_helper.dart';
import 'package:kamaae/models/expense.dart';
import 'package:kamaae/services/expense_service.dart';

import 'helpers/test_database.dart';

void main() {
  late ExpenseService service;
  late DatabaseHelper db;

  setUp(() async {
    await setUpTestDatabase();
    service = ExpenseService();
    db = DatabaseHelper();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('addExpense inserts and returns id', () async {
    final expense = Expense(
      category: 'Rent',
      amount: 15000,
      timestamp: DateTime(2026, 7, 11).millisecondsSinceEpoch,
    );
    final id = await service.addExpense(expense);
    expect(id, greaterThan(0));
  });

  test('getExpenses returns all expenses when no date filter', () async {
    await service.addExpense(
      Expense(
        category: 'Electricity',
        amount: 3000,
        timestamp: DateTime(2026, 7, 10).millisecondsSinceEpoch,
      ),
    );
    await service.addExpense(
      Expense(
        category: 'Staff',
        amount: 20000,
        timestamp: DateTime(2026, 7, 11).millisecondsSinceEpoch,
      ),
    );
    final all = await service.getExpenses();
    expect(all.length, 2);
  });

  test('getExpenses filters by date range', () async {
    final jul10 = DateTime(2026, 7, 10);
    final jul11 = DateTime(2026, 7, 11);
    final jul12 = DateTime(2026, 7, 12);

    await service.addExpense(
      Expense(category: 'Rent', amount: 1000, timestamp: jul10.millisecondsSinceEpoch),
    );
    await service.addExpense(
      Expense(category: 'Electricity', amount: 500, timestamp: jul11.millisecondsSinceEpoch),
    );
    await service.addExpense(
      Expense(category: 'Staff', amount: 2000, timestamp: jul12.millisecondsSinceEpoch),
    );

    final inRange = await service.getExpenses(from: jul10, to: jul12);
    expect(inRange.length, 2);
    expect(inRange.map((e) => e.category), containsAll(['Rent', 'Electricity']));
  });

  test('getTotalExpenses sums amounts correctly', () async {
    final from = DateTime(2026, 7, 1);
    final to = DateTime(2026, 7, 31, 23, 59, 59);

    await service.addExpense(
      Expense(category: 'Rent', amount: 15000, timestamp: DateTime(2026, 7, 5).millisecondsSinceEpoch),
    );
    await service.addExpense(
      Expense(category: 'Electricity', amount: 3000, timestamp: DateTime(2026, 7, 10).millisecondsSinceEpoch),
    );

    final total = await service.getTotalExpenses(from: from, to: to);
    expect(total, 18000);
  });

  test('deleteExpense removes the record', () async {
    final id = await service.addExpense(
      Expense(
        category: 'Packaging',
        amount: 500,
        timestamp: DateTime(2026, 7, 11).millisecondsSinceEpoch,
      ),
    );
    await service.deleteExpense(id);
    final all = await service.getExpenses();
    expect(all, isEmpty);
  });

  test('Expense.fromMap round-trips through toMap', () async {
    final expense = Expense(
      id: 1,
      category: 'Transport',
      amount: 800,
      note: 'Delivery van',
      timestamp: DateTime(2026, 7, 11).millisecondsSinceEpoch,
    );
    final restored = Expense.fromMap(expense.toMap());
    expect(restored.id, expense.id);
    expect(restored.category, expense.category);
    expect(restored.amount, expense.amount);
    expect(restored.note, expense.note);
    expect(restored.timestamp, expense.timestamp);
  });
}
