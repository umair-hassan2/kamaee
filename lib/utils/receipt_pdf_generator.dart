import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/sale.dart';
import '../models/transaction.dart';

class ReceiptPdfGenerator {
  static Future<Uint8List> generate({
    required Sale sale,
    required List<SaleTransaction> items,
    String? customerName,
    String shopName = 'Kamaae',
  }) async {
    final pdf = pw.Document();
    final dt = DateTime.fromMillisecondsSinceEpoch(sale.timestamp);
    final dateStr = DateFormat('d MMM yyyy, h:mm a').format(dt);

    final teal = PdfColor.fromHex('0D9488');
    final grey = PdfColor.fromHex('64748B');
    final lightGrey = PdfColor.fromHex('F1F5F9');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: teal,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    shopName,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    dateStr,
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 9),
                  ),
                  if (customerName != null && customerName.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      customerName,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Items header
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: pw.BoxDecoration(color: lightGrey),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text('Item',
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: grey)),
                  ),
                  pw.SizedBox(
                    width: 30,
                    child: pw.Text('Qty',
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: grey),
                        textAlign: pw.TextAlign.center),
                  ),
                  pw.SizedBox(
                    width: 50,
                    child: pw.Text('Amount',
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: grey),
                        textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
            ),

            // Items
            ...items.map(
              (line) => pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(
                          color: PdfColor.fromHex('E2E8F0'), width: 0.5)),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 4,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(line.itemName,
                              style: const pw.TextStyle(fontSize: 10)),
                          pw.Text(
                            'Rs. ${line.unitPrice.toStringAsFixed(0)} each',
                            style: pw.TextStyle(fontSize: 8, color: grey),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(
                      width: 30,
                      child: pw.Text(
                        '${line.quantity}',
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                    pw.SizedBox(
                      width: 50,
                      child: pw.Text(
                        'Rs. ${line.revenue.toStringAsFixed(0)}',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            pw.SizedBox(height: 8),

            // Totals
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: lightGrey,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                children: [
                  _totalRow('Total',
                      'Rs. ${sale.totalAmount.toStringAsFixed(0)}', bold: true),
                  if (sale.paidAmount > 0 &&
                      sale.paymentMethod != PaymentMethod.cash) ...[
                    pw.SizedBox(height: 4),
                    _totalRow('Paid',
                        'Rs. ${sale.paidAmount.toStringAsFixed(0)}',
                        color: teal),
                  ],
                  if (sale.khataAmount > 0) ...[
                    pw.SizedBox(height: 4),
                    _totalRow('On Khata',
                        'Rs. ${sale.khataAmount.toStringAsFixed(0)}',
                        color: PdfColor.fromHex('F59E0B')),
                  ],
                ],
              ),
            ),

            pw.SizedBox(height: 12),

            pw.Center(
              child: pw.Text(
                'Thank you!',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: teal),
              ),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _totalRow(String label, String value,
      {bool bold = false, PdfColor? color}) {
    final style = pw.TextStyle(
      fontSize: bold ? 12 : 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
    );
    return pw.Row(
      children: [
        pw.Expanded(child: pw.Text(label, style: style)),
        pw.Text(value, style: style),
      ],
    );
  }
}
