import 'package:intl/intl.dart';

class BillItem {
  final String name;
  final int qty;
  final double unitPrice;

  const BillItem({required this.name, required this.qty, required this.unitPrice});

  double get total => qty * unitPrice;
}

class BillFormatter {
  static String format({
    required List<BillItem> items,
    required double total,
    required double paid,
    required double balance,
    String? customerName,
  }) {
    final now = DateTime.now();
    final dateStr = DateFormat('d MMM yyyy, h:mm a').format(now);
    final buf = StringBuffer();

    buf.writeln('🧾 *BILL*');
    if (customerName != null && customerName.isNotEmpty) {
      buf.writeln('👤 $customerName');
    }
    buf.writeln('──────────────────');
    buf.writeln('📅 $dateStr');
    buf.writeln('');
    buf.writeln('ITEMS:');
    for (final item in items) {
      final nameCol = item.name.length > 14
          ? '${item.name.substring(0, 13)}…'
          : item.name.padRight(14);
      buf.writeln('• $nameCol  x${item.qty}    PKR ${item.total.toStringAsFixed(0)}');
    }
    buf.writeln('──────────────────');
    buf.writeln('Total:        PKR ${total.toStringAsFixed(0)}');
    buf.writeln('Paid:         PKR ${paid.toStringAsFixed(0)}');
    if (balance > 0) {
      buf.writeln('Balance on Khata: PKR ${balance.toStringAsFixed(0)}');
    }
    buf.writeln('──────────────────');
    buf.write('Thank you! 🙏');

    return buf.toString();
  }
}
