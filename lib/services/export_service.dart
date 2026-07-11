import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction.dart';

class ExportService {
  Future<void> exportTransactions(
    List<SaleTransaction> transactions,
    String periodLabel,
  ) async {
    final csv = _buildCsv(transactions);
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final stamp = '${now.year}${_pad(now.month)}${_pad(now.day)}';
    final filename =
        'kamaae_${periodLabel.toLowerCase().replaceAll(' ', '_')}_$stamp.csv';
    final file = File('${dir.path}/$filename');
    await file.writeAsString(csv);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Kamaae Transactions — $periodLabel',
    );
  }

  String _buildCsv(List<SaleTransaction> transactions) {
    final buf = StringBuffer();
    buf.writeln('Date,Time,Item,Type,Qty,Unit Price,Revenue,Cost,Profit');
    final df = DateFormat('dd/MM/yyyy');
    final tf = DateFormat('HH:mm');
    for (final t in transactions) {
      final isSell = t.type == TransactionType.sell;
      buf.writeln(
        '"${_esc(t.itemName)}",'
        '${df.format(t.timestamp)},'
        '${tf.format(t.timestamp)},'
        '${isSell ? "Sale" : "Restock"},'
        '${t.quantity},'
        '${(isSell ? t.unitPrice : t.unitCost).toStringAsFixed(0)},'
        '${t.revenue.toStringAsFixed(0)},'
        '${t.cost.toStringAsFixed(0)},'
        '${t.profit.toStringAsFixed(0)}',
      );
    }
    return buf.toString();
  }

  String _esc(String s) => s.replaceAll('"', '""');
  String _pad(int n) => n.toString().padLeft(2, '0');
}
