import '../database_helper.dart';
import '../models/finance_models.dart';
import '../models/item.dart';
import '../models/transaction.dart';

class FinanceService {
  final DatabaseHelper _db = DatabaseHelper();

  DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime startOfWeek(DateTime date) {
    final day = startOfDay(date);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month);

  (DateTime start, DateTime end) rangeForPeriod(FinancePeriod period) {
    final now = DateTime.now();
    final todayStart = startOfDay(now);

    switch (period) {
      case FinancePeriod.today:
        return (todayStart, todayStart.add(const Duration(days: 1)));
      case FinancePeriod.week:
        final start = startOfWeek(now);
        return (start, start.add(const Duration(days: 7)));
      case FinancePeriod.month:
        final start = startOfMonth(now);
        final end = DateTime(now.year, now.month + 1);
        return (start, end);
    }
  }

  Future<PeriodSummary> getSummaryForPeriod(FinancePeriod period) async {
    final (start, end) = rangeForPeriod(period);
    return getSummaryBetween(start, end);
  }

  Future<PeriodSummary> getTodaySummary() =>
      getSummaryForPeriod(FinancePeriod.today);

  Future<PeriodSummary> getSummaryBetween(DateTime start, DateTime end) async {
    final rows = await _db.getTransactionAggregatesBetween(start, end);

    double revenue = 0;
    double profit = 0;
    double cogs = 0;
    double restockSpend = 0;
    int unitsSold = 0;

    for (final row in rows) {
      final type = row['type'] as String;
      final quantity = row['quantity'] as int;
      final rowRevenue = (row['revenue'] as num).toDouble();
      final rowCost = (row['cost'] as num).toDouble();
      final rowProfit = (row['profit'] as num).toDouble();

      if (type == TransactionType.sell.name) {
        revenue += rowRevenue;
        profit += rowProfit;
        cogs += rowCost;
        unitsSold += quantity;
      } else {
        restockSpend += rowCost;
      }
    }

    return PeriodSummary(
      revenue: revenue,
      profit: profit,
      costOfGoodsSold: cogs,
      restockSpend: restockSpend,
      unitsSold: unitsSold,
      transactionCount: rows.length,
    );
  }

  Future<List<ChartDataPoint>> getChartData(FinancePeriod period) async {
    final (start, end) = rangeForPeriod(period);

    if (period == FinancePeriod.today) {
      return _hourlyChartData(start, end);
    }
    return _dailyChartData(start, end);
  }

  Future<List<ChartDataPoint>> _hourlyChartData(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await _db.getHourlyAggregatesBetween(start, end);
    final byHour = <int, ChartDataPoint>{};

    for (final row in rows) {
      final bucket = (row['hour_bucket'] as num).toInt();
      final hourStart = DateTime.fromMillisecondsSinceEpoch(bucket * 3600000);
      byHour[bucket] = ChartDataPoint(
        label: _formatHour(hourStart),
        revenue: (row['revenue'] as num?)?.toDouble() ?? 0,
        profit: (row['profit'] as num?)?.toDouble() ?? 0,
        cost: (row['cogs'] as num?)?.toDouble() ?? 0,
      );
    }

    final points = <ChartDataPoint>[];
    for (var h = 0; h < 24; h++) {
      final hourStart = start.add(Duration(hours: h));
      if (!hourStart.isBefore(end)) break;
      final bucket = hourStart.millisecondsSinceEpoch ~/ 3600000;
      points.add(
        byHour[bucket] ??
            ChartDataPoint(label: _formatHour(hourStart)),
      );
    }
    return points;
  }

  Future<List<ChartDataPoint>> _dailyChartData(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await _db.getDailyAggregatesBetween(start, end);
    final byDay = <int, ChartDataPoint>{};

    for (final row in rows) {
      final bucket = (row['day_bucket'] as num).toInt();
      final dayStart = DateTime.fromMillisecondsSinceEpoch(bucket * 86400000);
      final cogs = (row['cogs'] as num?)?.toDouble() ?? 0;
      final restock = (row['restock'] as num?)?.toDouble() ?? 0;
      byDay[bucket] = ChartDataPoint(
        label: _formatDay(dayStart),
        revenue: (row['revenue'] as num?)?.toDouble() ?? 0,
        profit: (row['profit'] as num?)?.toDouble() ?? 0,
        cost: cogs + restock,
      );
    }

    final points = <ChartDataPoint>[];
    var cursor = startOfDay(start);
    while (cursor.isBefore(end)) {
      final bucket = cursor.millisecondsSinceEpoch ~/ 86400000;
      points.add(byDay[bucket] ?? ChartDataPoint(label: _formatDay(cursor)));
      cursor = cursor.add(const Duration(days: 1));
    }
    return points;
  }

  Future<List<ProductBreakdown>> getTopProducts(FinancePeriod period) async {
    final (start, end) = rangeForPeriod(period);
    final rows = await _db.getTopProductsBetween(start, end);
    return rows
        .map(
          (row) => ProductBreakdown(
            itemName: row['item_name'] as String,
            revenue: (row['revenue'] as num).toDouble(),
            profit: (row['profit'] as num).toDouble(),
            quantity: (row['quantity'] as num).toInt(),
          ),
        )
        .toList();
  }

  Future<List<SaleTransaction>> getTransactions(FinancePeriod period) async {
    final (start, end) = rangeForPeriod(period);
    return _db.getTransactionsBetween(start, end);
  }

  Future<double> getInventoryValue() async {
    final items = await _db.getAllItems();
    return items.fold<double>(
      0,
      (sum, item) => sum + (item.purchasePrice * item.quantity),
    );
  }

  String _formatHour(DateTime time) {
    final hour = time.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display$period';
  }

  String _formatDay(DateTime date) => '${date.day}/${date.month}';
}

class InventoryFinanceLogger {
  final DatabaseHelper _db = DatabaseHelper();

  Future<void> logSell(Item item, int quantity) async {
    if (item.id == null) {
      throw StateError('Cannot log sale for item without id');
    }

    final revenue = item.sellingPrice * quantity;
    final cost = item.purchasePrice * quantity;

    await _db.insertTransaction(
      SaleTransaction(
        itemId: item.id!,
        itemName: item.name,
        type: TransactionType.sell,
        quantity: quantity,
        unitCost: item.purchasePrice,
        unitPrice: item.sellingPrice,
        revenue: revenue,
        cost: cost,
        profit: revenue - cost,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> logRestock(Item item, int quantity) async {
    if (item.id == null) {
      throw StateError('Cannot log restock for item without id');
    }

    final cost = item.purchasePrice * quantity;

    await _db.insertTransaction(
      SaleTransaction(
        itemId: item.id!,
        itemName: item.name,
        type: TransactionType.restock,
        quantity: quantity,
        unitCost: item.purchasePrice,
        unitPrice: 0,
        revenue: 0,
        cost: cost,
        profit: 0,
        timestamp: DateTime.now(),
      ),
    );
  }
}
