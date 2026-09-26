import 'package:kamaae/database_helper.dart';
import 'package:kamaae/models/cash_session.dart';
import 'package:kamaae/models/finance_models.dart';
import 'package:kamaae/models/item.dart';
import 'package:kamaae/models/sale.dart';
import 'package:kamaae/models/transaction.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> setUpTestDatabase() async {
  await DatabaseHelper.closeDatabase();
  DatabaseHelper.databasePathOverride = inMemoryDatabasePath;
  await DatabaseHelper().database;
}

Future<void> tearDownTestDatabase() async {
  await DatabaseHelper.closeDatabase();
  DatabaseHelper.databasePathOverride = null;
}

Future<Item> insertTestItem(
  DatabaseHelper db, {
  String barcode = '123456',
  String name = 'Test Item',
  double purchasePrice = 50,
  double sellingPrice = 100,
  int quantity = 10,
}) async {
  final item = Item(
    barcode: barcode,
    name: name,
    purchasePrice: purchasePrice,
    sellingPrice: sellingPrice,
    quantity: quantity,
  );
  final id = await db.insertItem(item);
  return item.copyWith(id: id);
}

Future<void> insertTestTransaction(
  DatabaseHelper db, {
  required Item item,
  required TransactionType type,
  required int quantity,
  required DateTime timestamp,
}) async {
  final unitCost = item.purchasePrice;
  final unitPrice = type == TransactionType.sell ? item.sellingPrice : 0.0;
  final revenue =
      type == TransactionType.sell ? item.sellingPrice * quantity : 0.0;
  final cost = unitCost * quantity;
  final profit = type == TransactionType.sell ? revenue - cost : 0.0;

  await db.insertTransaction(
    SaleTransaction(
      itemId: item.id!,
      itemName: item.name,
      type: type,
      quantity: quantity,
      unitCost: unitCost,
      unitPrice: unitPrice,
      revenue: revenue,
      cost: cost,
      profit: profit,
      timestamp: timestamp,
    ),
  );
}

/// Moves a session's open time into the past so the cash window under test
/// spans a deterministic range instead of a sub-millisecond one.
Future<CashSession> backdateSession(
  DatabaseHelper db,
  CashSession session, {
  Duration ago = const Duration(hours: 1),
}) async {
  final openedAt = DateTime.now().subtract(ago).millisecondsSinceEpoch;
  final database = await db.database;
  await database.update(
    'cash_sessions',
    {'opened_at': openedAt},
    where: 'id = ?',
    whereArgs: [session.id],
  );
  return CashSession(
    id: session.id,
    openingCash: session.openingCash,
    openedAt: openedAt,
  );
}

Future<Sale> insertTestSale(
  DatabaseHelper db, {
  required double totalAmount,
  required double paidAmount,
  required DateTime timestamp,
  SaleStatus status = SaleStatus.completed,
  PaymentMethod paymentMethod = PaymentMethod.cash,
  int? customerId,
}) async {
  final sale = Sale(
    customerId: customerId,
    totalAmount: totalAmount,
    paidAmount: paidAmount,
    khataAmount: totalAmount - paidAmount,
    paymentMethod: paymentMethod,
    status: status,
    timestamp: timestamp.millisecondsSinceEpoch,
  );
  final id = await db.insertSale(sale);
  return sale.copyWith(id: id);
}

String chartHourLabel(int hour) {
  final period = hour >= 12 ? 'PM' : 'AM';
  final display = hour % 12 == 0 ? 12 : hour % 12;
  return '$display$period';
}

String chartDayLabel(DateTime date) => '${date.day}/${date.month}';

ChartDataPoint chartPointForLabel(List<ChartDataPoint> points, String label) {
  return points.firstWhere((point) => point.label == label);
}
