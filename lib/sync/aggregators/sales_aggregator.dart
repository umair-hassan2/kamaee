import 'package:cloud_firestore/cloud_firestore.dart';
import '../../database_helper.dart';
import '../../services/finance_service.dart';
import '../data_aggregator.dart';

class SalesAggregator extends DataAggregator {
  final _db = DatabaseHelper();
  final _finance = FinanceService();

  @override
  Future<void> aggregate(DocumentReference shopRef) async {
    final now = DateTime.now();
    final todayStart = _startOfDay(now);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = _startOfWeek(now);

    final results = await Future.wait([
      _computeSnapshot(todayStart, todayStart.add(const Duration(days: 1))),
      _computeSnapshot(yesterdayStart, todayStart),
      _computeSnapshot(weekStart, now),
    ]);

    final todaySnap = results[0];
    final yesterdaySnap = results[1];
    final weekSnap = results[2];

    final batch = FirebaseFirestore.instance.batch();
    final snapshots = shopRef.collection('snapshots');

    batch.set(snapshots.doc('today'), {
      ...todaySnap,
      'vs_yesterday': {
        'revenue_delta_pct': _pctChange(
          yesterdaySnap['revenue'] as double,
          todaySnap['revenue'] as double,
        ),
        'profit_delta_pct': _pctChange(
          yesterdaySnap['profit'] as double,
          todaySnap['profit'] as double,
        ),
      },
      'synced_at': FieldValue.serverTimestamp(),
    });

    batch.set(snapshots.doc('yesterday'), {
      ...yesterdaySnap,
      'synced_at': FieldValue.serverTimestamp(),
    });

    batch.set(snapshots.doc('this_week'), {
      ...weekSnap,
      'synced_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<Map<String, dynamic>> _computeSnapshot(
    DateTime start,
    DateTime end,
  ) async {
    final summary = await _finance.getSummaryBetween(start, end);
    final topSellers = await _db.getTopProductsBetween(start, end);
    final txCount = (await _db.getCompletedSalesBetween(start, end)).length;

    return {
      'date': _dateStr(start),
      'revenue': summary.revenue,
      'profit': summary.profit,
      'margin_pct': summary.revenue > 0
          ? _round2(summary.profit / summary.revenue * 100)
          : 0.0,
      'tx_count': txCount,
      'avg_basket': txCount > 0 ? _round2(summary.revenue / txCount) : 0.0,
      'top_sellers': topSellers
          .map((r) => {
                'name': r['item_name'] as String,
                'qty_sold': (r['quantity'] as num).toInt(),
                'revenue': (r['revenue'] as num).toDouble(),
              })
          .toList(),
    };
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _startOfWeek(DateTime d) {
    final day = _startOfDay(d);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  double _pctChange(double old, double current) {
    if (old == 0) return current > 0 ? 100.0 : 0.0;
    return _round1((current - old) / old * 100);
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  double _round1(double v) => double.parse(v.toStringAsFixed(1));
  double _round2(double v) => double.parse(v.toStringAsFixed(2));
}
