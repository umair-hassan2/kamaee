import 'package:cloud_firestore/cloud_firestore.dart';
import '../../database_helper.dart';
import '../../services/khata_service.dart';
import '../data_aggregator.dart';

class KhataAggregator extends DataAggregator {
  final _db = DatabaseHelper();
  final _khata = KhataService();

  @override
  Future<void> aggregate(DocumentReference shopRef) async {
    final customers = await _khata.getCustomers();
    final activeDebtors = customers.where((c) => c.balance > 0).toList();
    final totalOutstanding =
        activeDebtors.fold<double>(0, (acc, c) => acc + c.balance);

    final oldestCredit = await _db.getOldestCreditTimestampPerCustomer();
    final thirtyDaysAgoMs = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;

    int overdueCount = 0;
    for (final c in activeDebtors) {
      final oldest = oldestCredit[c.id];
      if (oldest != null && oldest < thirtyDaysAgoMs) overdueCount++;
    }

    final topDebtors = (List.of(activeDebtors)
          ..sort((a, b) => b.balance.compareTo(a.balance)))
        .take(5)
        .map((c) => {'name': c.name, 'outstanding': c.balance})
        .toList();

    await shopRef.collection('khata').doc('summary').set({
      'total_outstanding': totalOutstanding,
      'active_debtors': activeDebtors.length,
      'overdue_count': overdueCount,
      'top_debtors': topDebtors,
      'synced_at': FieldValue.serverTimestamp(),
    });
  }
}
