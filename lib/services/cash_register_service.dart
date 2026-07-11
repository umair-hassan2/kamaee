import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../models/cash_session.dart';
import '../models/transaction.dart';

class CashRegisterService {
  Future<Database> get _db async => DatabaseHelper().database;

  Future<double> getExpectedCashForSession(CashSession session) async {
    final salesRevenue = await _getSalesRevenueSince(session.openedAt);
    return session.openingCash + salesRevenue;
  }

  Future<CashSession?> getActiveSession() async {
    final db = await _db;
    final rows = await db.query(
      'cash_sessions',
      where: 'closed_at IS NULL',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CashSession.fromMap(rows.first);
  }

  Future<CashSession> openSession(double openingCash) async {
    final existing = await getActiveSession();
    if (existing != null) {
      throw StateError('A cash session is already open.');
    }
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert('cash_sessions', {
      'opening_cash': openingCash,
      'opened_at': now,
    });
    return CashSession(id: id, openingCash: openingCash, openedAt: now);
  }

  Future<double> _getSalesRevenueSince(int openedAt) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT SUM(revenue) AS total FROM transactions '
      'WHERE type = ? AND timestamp >= ?',
      [TransactionType.sell.name, openedAt],
    );
    return (rows.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<int> getSalesCountSince(int openedAt) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM transactions '
      'WHERE type = ? AND timestamp >= ?',
      [TransactionType.sell.name, openedAt],
    );
    return (rows.first['cnt'] as num?)?.toInt() ?? 0;
  }

  Future<CashSession> closeSession(
    double closingCash, {
    String? notes,
  }) async {
    final session = await getActiveSession();
    if (session == null) throw StateError('No active cash session.');

    final salesRevenue = await _getSalesRevenueSince(session.openedAt);
    final expectedCash = session.openingCash + salesRevenue;
    final discrepancy = closingCash - expectedCash;
    final now = DateTime.now().millisecondsSinceEpoch;

    final db = await _db;
    await db.update(
      'cash_sessions',
      {
        'closing_cash': closingCash,
        'expected_cash': expectedCash,
        'discrepancy': discrepancy,
        'closed_at': now,
        'notes': notes,
      },
      where: 'id = ?',
      whereArgs: [session.id],
    );

    return CashSession(
      id: session.id,
      openingCash: session.openingCash,
      closingCash: closingCash,
      expectedCash: expectedCash,
      discrepancy: discrepancy,
      openedAt: session.openedAt,
      closedAt: now,
      notes: notes,
    );
  }

  Future<List<CashSession>> getSessionHistory() async {
    final db = await _db;
    final rows = await db.query(
      'cash_sessions',
      where: 'closed_at IS NOT NULL',
      orderBy: 'opened_at DESC',
    );
    return rows.map((r) => CashSession.fromMap(r)).toList();
  }
}
