import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/sale.dart';
import '../models/transaction.dart';

// Design-system colours (screen 18 spec)
const _ink = PdfColor(0.090, 0.078, 0.055);         // #17140E
const _paper = PdfColor(0.965, 0.953, 0.925);       // #F6F3EC
const _green = PdfColor(0.071, 0.451, 0.306);       // #12734E
const _greenDark = PdfColor(0.055, 0.369, 0.251);   // #0E5E40
const _amber = PdfColor(0.663, 0.416, 0.071);       // #A96A12
const _border = PdfColor(0.918, 0.890, 0.839);      // #EAE3D6
const _muted = PdfColor(0.545, 0.506, 0.451);       // #8B8173
const _mutedLight = PdfColor(0.706, 0.671, 0.612);  // #B4AB9C
const _onDark = PdfColor(0.984, 0.976, 0.953);      // #FBF9F3
const _headingDark = PdfColor(0.604, 0.569, 0.506); // #9A9184

class ReceiptPdfGenerator {
  static Future<Uint8List> generate({
    required Sale sale,
    required List<SaleTransaction> items,
    String? customerName,
    String shopName = 'Kamaae',
    String? shopAddress,
    String? shopPhone,
    int? billNumber,
  }) async {
    final pdf = pw.Document();
    final dt = DateTime.fromMillisecondsSinceEpoch(sale.timestamp);
    final dateStr = DateFormat("d MMM yyyy, h:mm a").format(dt);
    final billNum = billNumber ?? sale.id ?? 0;
    final billId = 'KAM-$billNum-${DateFormat("ddMMyyyy").format(dt)}';

    final isPartial = sale.paymentMethod == PaymentMethod.partial;
    final isKhata = sale.paymentMethod == PaymentMethod.khata;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5.copyWith(
          marginTop: 0,
          marginBottom: 0,
          marginLeft: 0,
          marginRight: 0,
        ),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // ── Header: ink bg, K logo, shop name ──────────────────────────
            pw.Container(
              color: _ink,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 22, vertical: 18),
              child: pw.Row(
                children: [
                  // "K" monogram box
                  pw.Container(
                    width: 48,
                    height: 48,
                    decoration: pw.BoxDecoration(
                      color: _paper,
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      'K',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: _green,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 14),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          shopName,
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: _onDark,
                          ),
                        ),
                        if (shopAddress != null || shopPhone != null)
                          pw.SizedBox(height: 3),
                        if (shopAddress != null || shopPhone != null)
                          pw.Text(
                            [
                              if (shopAddress != null) shopAddress,
                              if (shopPhone != null) shopPhone,
                            ].join(' · '),
                            style: pw.TextStyle(
                                fontSize: 9, color: _headingDark),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Billed-to row ───────────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'BILLED TO',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1.0,
                              color: _muted),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          customerName?.isNotEmpty == true
                              ? customerName!
                              : 'Walk-in Customer',
                          style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: _ink),
                        ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        '#$billNum',
                        style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: _ink),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        dateStr,
                        style: pw.TextStyle(fontSize: 9, color: _muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 14),

            // ── Items table ─────────────────────────────────────────────────
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 22),
              child: pw.Column(
                children: [
                  // Table header
                  pw.Container(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                          bottom: pw.BorderSide(color: _border, width: 1)),
                    ),
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text('ITEM',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: _muted)),
                        ),
                        pw.SizedBox(
                          width: 36,
                          child: pw.Text('QTY',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: _muted)),
                        ),
                        pw.SizedBox(
                          width: 62,
                          child: pw.Text('AMOUNT',
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: _muted)),
                        ),
                      ],
                    ),
                  ),
                  // Item rows
                  ...items.map((line) => pw.Container(
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                              bottom: pw.BorderSide(
                                  color: PdfColor(0.945, 0.925, 0.882),
                                  width: 0.5)),
                        ),
                        padding: const pw.EdgeInsets.symmetric(vertical: 9),
                        child: pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment:
                                    pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    line.itemName,
                                    style: const pw.TextStyle(fontSize: 11),
                                  ),
                                  pw.SizedBox(height: 1),
                                  pw.Text(
                                    'Rs ${line.unitPrice.toStringAsFixed(0)} each',
                                    style: pw.TextStyle(
                                        fontSize: 8, color: _muted),
                                  ),
                                ],
                              ),
                            ),
                            pw.SizedBox(
                              width: 36,
                              child: pw.Text(
                                '${line.quantity}',
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(fontSize: 11),
                              ),
                            ),
                            pw.SizedBox(
                              width: 62,
                              child: pw.Text(
                                'Rs ${line.revenue.toStringAsFixed(0)}',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),

            pw.SizedBox(height: 10),

            // ── Summary box ─────────────────────────────────────────────────
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 22),
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: _paper,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(
                children: [
                  if (sale.discountAmount > 0) ...[
                    _summaryRow(
                      'Subtotal',
                      'Rs ${(sale.totalAmount + sale.discountAmount).toStringAsFixed(0)}',
                      color: _muted,
                    ),
                    pw.SizedBox(height: 5),
                    _summaryRow(
                      'Discount',
                      '− Rs ${sale.discountAmount.toStringAsFixed(0)}',
                      color: PdfColor(0.725, 0.231, 0.196),
                    ),
                    pw.Container(
                      height: 1,
                      color: _border,
                      margin: const pw.EdgeInsets.symmetric(vertical: 10),
                    ),
                  ],
                  _summaryRow(
                    'Total',
                    'Rs ${sale.totalAmount.toStringAsFixed(0)}',
                    bold: true,
                    fontSize: 15,
                  ),
                  pw.Container(
                    height: 1,
                    color: _border,
                    margin: const pw.EdgeInsets.symmetric(vertical: 10),
                  ),
                  if (sale.paidAmount > 0) ...[
                    _summaryRow(
                      'Paid now',
                      'Rs ${sale.paidAmount.toStringAsFixed(0)}',
                      color: _greenDark,
                    ),
                    pw.SizedBox(height: 5),
                  ],
                  if (sale.khataAmount > 0)
                    _summaryRow(
                      'Balance on Khata',
                      'Rs ${sale.khataAmount.toStringAsFixed(0)}',
                      color: _amber,
                      bold: true,
                    ),
                ],
              ),
            ),

            // ── Payment badge ───────────────────────────────────────────────
            if (isPartial || isKhata) ...[
              pw.SizedBox(height: 10),
              pw.Container(
                margin: const pw.EdgeInsets.symmetric(horizontal: 22),
                child: pw.Row(
                  children: [
                    pw.Text(
                      isPartial ? 'Partial Payment' : 'On Khata',
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: _amber),
                    ),
                  ],
                ),
              ),
            ],

            pw.Spacer(),

            // ── Barcode decoration ──────────────────────────────────────────
            pw.Container(
              margin: const pw.EdgeInsets.fromLTRB(22, 14, 22, 0),
              height: 36,
              child: pw.Row(
                children: _barcodeStripes(),
              ),
            ),
            pw.Container(
              margin: const pw.EdgeInsets.fromLTRB(22, 5, 22, 0),
              child: pw.Center(
                child: pw.Text(
                  billId,
                  style: pw.TextStyle(
                      fontSize: 8,
                      letterSpacing: 1.0,
                      color: _muted),
                ),
              ),
            ),

            // ── Footer ──────────────────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.fromLTRB(22, 14, 22, 22),
              child: pw.Column(
                children: [
                  pw.Center(
                    child: pw.Text(
                      'Shukriya!  ·  Thank you',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: _green,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Center(
                    child: pw.Text(
                      'Powered by Kamaae',
                      style: pw.TextStyle(fontSize: 9, color: _mutedLight),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    double fontSize = 12,
    PdfColor? color,
  }) {
    final style = pw.TextStyle(
      fontSize: fontSize,
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

  // Simple barcode-style decorative stripes using the design's pattern
  static List<pw.Widget> _barcodeStripes() {
    // Widths from the design HTML: 2,1,1,2,3,1,1,1,2,2,1,1,3,1,2,1,1,2,1,3
    final pattern = [2, 1, 1, 2, 3, 1, 1, 1, 2, 2, 1, 1, 3, 1, 2, 1, 1, 2, 1, 3];
    final widgets = <pw.Widget>[];
    for (var i = 0; i < pattern.length; i++) {
      widgets.add(pw.Expanded(
        flex: pattern[i],
        child: pw.Container(
            color: i.isEven ? _ink : PdfColors.white),
      ));
    }
    return widgets;
  }
}
