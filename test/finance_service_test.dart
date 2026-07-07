import 'package:flutter_test/flutter_test.dart';
import 'package:kamaae/database_helper.dart';
import 'package:kamaae/models/finance_models.dart';
import 'package:kamaae/models/transaction.dart';
import 'package:kamaae/services/finance_service.dart';
import 'package:kamaae/services/inventory_service.dart';

import 'helpers/test_database.dart';

void main() {
  late FinanceService finance;
  late InventoryService inventory;
  late DatabaseHelper db;

  setUp(() async {
    await setUpTestDatabase();
    finance = FinanceService();
    inventory = InventoryService();
    db = DatabaseHelper();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('date helpers normalize day week and month', () {
    final date = DateTime(2026, 7, 8, 15, 30); // Wednesday

    expect(finance.startOfDay(date), DateTime(2026, 7, 8));
    expect(finance.startOfWeek(date), DateTime(2026, 7, 6)); // Monday
    expect(finance.startOfMonth(date), DateTime(2026, 7));
  });

  test('today summary aggregates sales and restocks', () async {
    final item = await insertTestItem(
      db,
      purchasePrice: 50,
      sellingPrice: 100,
      quantity: 20,
    );

    await inventory.sellItem(item, 2);
    await inventory.restockItem(item.copyWith(quantity: 18), 5);

    final summary = await finance.getTodaySummary();

    expect(summary.revenue, 200);
    expect(summary.profit, 100);
    expect(summary.costOfGoodsSold, 100);
    expect(summary.restockSpend, 250);
    expect(summary.unitsSold, 2);
    expect(summary.transactionCount, 2);
  });

  test('getSummaryBetween excludes transactions outside range', () async {
    final item = await insertTestItem(db);
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    await insertTestTransaction(
      db,
      item: item,
      type: TransactionType.sell,
      quantity: 1,
      timestamp: todayStart.add(const Duration(hours: 10)),
    );
    await insertTestTransaction(
      db,
      item: item,
      type: TransactionType.sell,
      quantity: 1,
      timestamp: todayStart.subtract(const Duration(days: 1, hours: -10)),
    );

    final summary = await finance.getSummaryBetween(
      todayStart,
      todayStart.add(const Duration(days: 1)),
    );

    expect(summary.revenue, 100);
    expect(summary.transactionCount, 1);
  });

  test('getInventoryValue sums purchase price times quantity', () async {
    await insertTestItem(db, purchasePrice: 50, quantity: 4, barcode: 'A');
    await insertTestItem(
      db,
      purchasePrice: 20,
      quantity: 10,
      barcode: 'B',
      name: 'Other',
    );

    expect(await finance.getInventoryValue(), 400);
  });

  test('getTopProducts ranks by revenue with profit and quantity', () async {
    final soap = await insertTestItem(
      db,
      barcode: 'soap',
      name: 'Soap',
      purchasePrice: 40,
      sellingPrice: 100,
      quantity: 10,
    );
    final oil = await insertTestItem(
      db,
      barcode: 'oil',
      name: 'Oil',
      purchasePrice: 80,
      sellingPrice: 200,
      quantity: 10,
    );

    await inventory.sellItem(soap, 1);
    await inventory.sellItem(oil, 2);

    final top = await finance.getTopProducts(FinancePeriod.today);

    expect(top, hasLength(2));
    expect(top.first.itemName, 'Oil');
    expect(top.first.revenue, 400);
    expect(top.first.profit, 240);
    expect(top.first.quantity, 2);
    expect(top.last.itemName, 'Soap');
    expect(top.last.profit, 60);
  });

  test('hourly chart aggregates revenue profit and cogs for today', () async {
    final item = await insertTestItem(
      db,
      purchasePrice: 50,
      sellingPrice: 100,
    );
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    const saleHour = 11;

    await insertTestTransaction(
      db,
      item: item,
      type: TransactionType.sell,
      quantity: 3,
      timestamp: todayStart.add(const Duration(hours: saleHour)),
    );

    final chart = await finance.getChartData(FinancePeriod.today);
    final bucket = chartPointForLabel(chart, chartHourLabel(saleHour));

    expect(chart, hasLength(24));
    expect(bucket.revenue, 300);
    expect(bucket.profit, 150);
    expect(bucket.cost, 150);

    final emptyBucket = chartPointForLabel(chart, chartHourLabel(6));
    expect(emptyBucket.revenue, 0);
    expect(emptyBucket.profit, 0);
  });

  test('weekly daily chart aggregates revenue profit and total costs', () async {
    final item = await insertTestItem(
      db,
      purchasePrice: 50,
      sellingPrice: 100,
    );
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    await insertTestTransaction(
      db,
      item: item,
      type: TransactionType.sell,
      quantity: 2,
      timestamp: todayStart.add(const Duration(hours: 9)),
    );
    await insertTestTransaction(
      db,
      item: item,
      type: TransactionType.restock,
      quantity: 4,
      timestamp: todayStart.add(const Duration(hours: 10)),
    );

    final chart = await finance.getChartData(FinancePeriod.week);
    final nonEmpty = chart.where((point) => point.revenue > 0).toList();

    expect(chart, hasLength(7));
    expect(nonEmpty, hasLength(1));
    expect(nonEmpty.first.revenue, 200);
    expect(nonEmpty.first.profit, 100);
    expect(nonEmpty.first.cost, 300); // 100 cogs + 200 restock
    expect(chart.where((point) => point.revenue == 0), hasLength(6));
  });

  test('monthly daily chart includes every day with zero-filled gaps', () async {
    final item = await insertTestItem(db, sellingPrice: 100, purchasePrice: 50);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    await insertTestTransaction(
      db,
      item: item,
      type: TransactionType.sell,
      quantity: 1,
      timestamp: todayStart.add(const Duration(hours: 14)),
    );

    final chart = await finance.getChartData(FinancePeriod.month);
    final nonEmpty = chart.where((point) => point.revenue > 0).toList();

    expect(chart, hasLength(daysInMonth));
    expect(nonEmpty, hasLength(1));
    expect(nonEmpty.first.revenue, 100);
    expect(nonEmpty.first.profit, 50);
    expect(chart.where((point) => point.revenue == 0), hasLength(daysInMonth - 1));
  });

  test('getTransactions returns period sales and restocks newest first', () async {
    final item = await insertTestItem(db);
    final todayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    await insertTestTransaction(
      db,
      item: item,
      type: TransactionType.sell,
      quantity: 1,
      timestamp: todayStart.add(const Duration(hours: 9)),
    );
    await insertTestTransaction(
      db,
      item: item,
      type: TransactionType.restock,
      quantity: 2,
      timestamp: todayStart.add(const Duration(hours: 11)),
    );

    final txs = await finance.getTransactions(FinancePeriod.today);

    expect(txs, hasLength(2));
    expect(txs.first.type, TransactionType.restock);
    expect(txs.last.type, TransactionType.sell);
  });
}
