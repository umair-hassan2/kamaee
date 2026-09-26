import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../models/cash_session.dart';
import '../models/sale.dart';
import '../models/transaction.dart';

class CashRegisterService {
  Future<Database> get _db async => DatabaseHelper().database;

  Future<double> getExpectedCashForSession(CashSession session) async {
    final cashReceived = await _getCashReceivedSince(
      session.openedAt,
      DateTime.now().millisecondsSinceEpoch,
    );
    return session.openingCash + cashReceived;
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

  /// Cash actually received in the half-open window [openedAt, upperBoundMs):
  /// amounts paid on completed checkout sales, plus direct-sell revenue.
  /// Credit (khata) revenue never reaches the drawer and is excluded.
  Future<double> _getCashReceivedSince(int openedAt, int upperBoundMs) async {
    final db = await _db;

    final saleRows = await db.rawQuery(
      'SELECT SUM(paid_amount) AS total FROM sales '
      'WHERE status = ? AND timestamp >= ? AND timestamp < ?',
      [SaleStatus.completed.name, openedAt, upperBoundMs],
    );
    final directSellRows = await db.rawQuery(
      'SELECT SUM(revenue) AS total FROM transactions '
      'WHERE type = ? AND sale_id IS NULL '
      'AND timestamp >= ? AND timestamp < ?',
      [TransactionType.sell.name, openedAt, upperBoundMs],
    );

    final paid = (saleRows.first['total'] as num?)?.toDouble() ?? 0.0;
    final directSells =
        (directSellRows.first['total'] as num?)?.toDouble() ?? 0.0;
    return paid + directSells;
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
    final closeInitiatedAt = DateTime.now().millisecondsSinceEpoch;
    final session = await getActiveSession();
    if (session == null) throw StateError('No active cash session.');

    final cashReceived = await _getCashReceivedSince(
      session.openedAt,
      closeInitiatedAt,
    );
    final expectedCash = session.openingCash + cashReceived;
    final discrepancy = closingCash - expectedCash;

    final db = await _db;
    await db.update(
      'cash_sessions',
      {
        'closing_cash': closingCash,
        'expected_cash': expectedCash,
        'discrepancy': discrepancy,
        'closed_at': closeInitiatedAt,
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
      closedAt: closeInitiatedAt,
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
