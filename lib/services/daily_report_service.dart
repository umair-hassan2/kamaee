import '../database_helper.dart';
import '../models/finance_models.dart';
import '../models/item.dart';
import '../services/finance_service.dart';
import '../services/khata_service.dart';
import '../utils/currency_formatter.dart';

class DailyReportService {
  final _finance = FinanceService();
  final _khata = KhataService();
  final _db = DatabaseHelper();

  Future<String> generateTodayReport() async {
    final now = DateTime.now();
    final start = _finance.startOfDay(now);
    final end = start.add(const Duration(days: 1));

    final results = await Future.wait([
      _finance.getTodaySummary(),
      _db.getCompletedSalesBetween(start, end),
      _db.getTopProductsBetween(start, end, limit: 1),
      _db.getAllItems(),
      _khata.getTotalOutstanding(),
    ]);

    final summary = results[0] as PeriodSummary;
    final salesCount = (results[1] as List).length;
    final topProducts = results[2] as List<Map<String, dynamic>>;
    final allItems = results[3] as List<Item>;
    final outstanding = results[4] as double;

    final lowStock = allItems.where((item) => item.quantity <= 5).toList()
      ..sort((a, b) => a.quantity.compareTo(b.quantity));

    final dateStr = _formatDate(now);
    final margin = summary.marginPercent.toStringAsFixed(0);
    final buf = StringBuffer();

    buf.writeln('📊 *Kamaae Daily Report — $dateStr*');
    buf.writeln();
    buf.writeln('💰 Revenue: ${formatPkr(summary.revenue)}');
    buf.writeln(
        '📈 Profit: ${formatPkr(summary.profit)} ($margin% margin)');
    buf.writeln('🛒 Transactions: $salesCount');

    if (lowStock.isNotEmpty) {
      buf.writeln();
      buf.writeln('⚠️ Low Stock (${lowStock.length} items):');
      for (final item in lowStock) {
        final indicator = item.quantity == 0 ? '❌' : '— ${item.quantity} left';
        buf.writeln('  • ${item.name} $indicator');
      }
    }

    buf.writeln();
    buf.writeln('💳 Outstanding Khata: ${formatPkr(outstanding)}');

    if (topProducts.isNotEmpty) {
      final top = topProducts.first;
      final name = top['item_name'] as String;
      final qty = (top['quantity'] as num).toInt();
      buf.writeln();
      buf.writeln('🔥 Top Seller: $name ($qty sold)');
    }

    return buf.toString().trimRight();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}
