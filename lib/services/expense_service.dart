import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../models/expense.dart';

class ExpenseService {
  Future<Database> get _db async => DatabaseHelper().database;

  Future<int> addExpense(Expense expense) async {
    final db = await _db;
    return db.insert('expenses', expense.toMap());
  }

  Future<List<Expense>> getExpenses({DateTime? from, DateTime? to}) async {
    final db = await _db;
    String? where;
    List<Object?>? whereArgs;
    if (from != null && to != null) {
      where = 'timestamp >= ? AND timestamp < ?';
      whereArgs = [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch];
    } else if (from != null) {
      where = 'timestamp >= ?';
      whereArgs = [from.millisecondsSinceEpoch];
    }
    final rows = await db.query(
      'expenses',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
    );
    return rows.map((r) => Expense.fromMap(r)).toList();
  }

  Future<void> deleteExpense(int id) async {
    final db = await _db;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getTotalExpenses({DateTime? from, DateTime? to}) async {
    final expenses = await getExpenses(from: from, to: to);
    double total = 0;
    for (final e in expenses) {
      total += e.amount;
    }
    return total;
  }
}
