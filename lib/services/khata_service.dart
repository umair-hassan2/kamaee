import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../models/customer.dart';
import '../models/khata_entry.dart';

class KhataService {
  Future<Database> get _db async => DatabaseHelper().database;

  // ─── Customers ───────────────────────────────────────────────────────────────

  Future<int> addCustomer(Customer customer) async {
    final db = await _db;
    return db.insert('customers', customer.toMap());
  }

  Future<List<Customer>> getCustomers() async {
    final db = await _db;
    final rows = await db.query('customers', orderBy: 'name COLLATE NOCASE ASC');
    final List<Customer> result = [];
    for (final row in rows) {
      final balance = await getBalance(row['id'] as int);
      result.add(Customer.fromMap(row).copyWith(balance: balance));
    }
    return result;
  }

  Future<Customer?> getCustomerById(int id) async {
    final db = await _db;
    final rows = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final balance = await getBalance(id);
    return Customer.fromMap(rows.first).copyWith(balance: balance);
  }

  Future<void> deleteCustomer(int id) async {
    final db = await _db;
    await db.delete('khata_entries', where: 'customer_id = ?', whereArgs: [id]);
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  // ─── Entries ─────────────────────────────────────────────────────────────────

  Future<int> addEntry(KhataEntry entry) async {
    final db = await _db;
    return db.insert('khata_entries', entry.toMap());
  }

  Future<void> deleteEntry(int id) async {
    final db = await _db;
    await db.delete('khata_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<KhataEntry>> getEntriesForCustomer(int customerId) async {
    final db = await _db;
    final rows = await db.query(
      'khata_entries',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'timestamp DESC',
    );
    return rows.map((r) => KhataEntry.fromMap(r)).toList();
  }

  // ─── Aggregates ──────────────────────────────────────────────────────────────

  Future<double> getTotalOutstanding() async {
    final db = await _db;
    // Sum per customer: credit - payment, then sum positives only
    final rows = await db.rawQuery(
      'SELECT customer_id, '
      'SUM(CASE WHEN type = ? THEN amount ELSE 0 END) - '
      'SUM(CASE WHEN type = ? THEN amount ELSE 0 END) AS balance '
      'FROM khata_entries '
      'GROUP BY customer_id',
      [KhataEntryType.credit.name, KhataEntryType.payment.name],
    );
    double total = 0;
    for (final row in rows) {
      final balance = (row['balance'] as num?)?.toDouble() ?? 0;
      if (balance > 0) total += balance;
    }
    return total;
  }

  /// Returns all entries since the last time the running balance hit zero.
  /// If the balance never hit zero, returns all entries.
  Future<List<KhataEntry>> getEntriesSinceLastSettlement(int customerId) async {
    final db = await _db;
    final rows = await db.query(
      'khata_entries',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'timestamp ASC',
    );
    final allEntries = rows.map((r) => KhataEntry.fromMap(r)).toList();
    double runningBalance = 0;
    int lastZeroIndex = -1;
    for (int i = 0; i < allEntries.length; i++) {
      final e = allEntries[i];
      runningBalance += e.type == KhataEntryType.credit ? e.amount : -e.amount;
      if (runningBalance <= 0) lastZeroIndex = i;
    }
    return allEntries.sublist(lastZeroIndex + 1);
  }

  Future<double> getBalance(int customerId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT '
      'SUM(CASE WHEN type = ? THEN amount ELSE 0 END) - '
      'SUM(CASE WHEN type = ? THEN amount ELSE 0 END) AS balance '
      'FROM khata_entries WHERE customer_id = ?',
      [KhataEntryType.credit.name, KhataEntryType.payment.name, customerId],
    );
    if (rows.isEmpty) return 0;
    return (rows.first['balance'] as num?)?.toDouble() ?? 0;
  }
}
