import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/app_settings.dart';
import '../models/customer.dart';
import '../models/khata_entry.dart';

// Shared design-system colours (same as receipt_pdf_generator.dart)
const _ink = PdfColor(0.090, 0.078, 0.055);
const _paper = PdfColor(0.965, 0.953, 0.925);
const _green = PdfColor(0.071, 0.451, 0.306);
const _greenDark = PdfColor(0.055, 0.369, 0.251);
const _amber = PdfColor(0.663, 0.416, 0.071);
const _red = PdfColor(0.725, 0.231, 0.196);
const _border = PdfColor(0.918, 0.890, 0.839);
const _muted = PdfColor(0.545, 0.506, 0.451);
const _mutedLight = PdfColor(0.706, 0.671, 0.612);
const _onDark = PdfColor(0.984, 0.976, 0.953);
const _headingDark = PdfColor(0.604, 0.569, 0.506);
const _amberLight = PdfColor(0.969, 0.922, 0.835);

class KhataStatementPdfGenerator {
  static Future<Uint8List> generate({
    required Customer customer,
    required List<KhataEntry> entries,
    required double outstandingBalance,
    required List<ShopPaymentMethod> paymentMethods,
    String shopName = 'Kamaae',
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final generatedAt = DateFormat('d MMM yyyy, h:mm a').format(now);
    final statementId =
        'KHT-${customer.id}-${DateFormat("ddMMyyyy").format(now)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginTop: 0,
          marginBottom: 0,
          marginLeft: 0,
          marginRight: 0,
        ),
        footer: (ctx) => _buildFooter(statementId, ctx.pageNumber, ctx.pagesCount),
        build: (ctx) => [
          // ── Header ──────────────────────────────────────────────────────
          _buildHeader(shopName),

          // ── Statement info ───────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(28, 20, 28, 0),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'STATEMENT FOR',
                        style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.0,
                            color: _muted),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        customer.name,
                        style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: _ink),
                      ),
                      if (customer.phone.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text(
                          customer.phone,
                          style: pw.TextStyle(fontSize: 10, color: _muted),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'KHATA STATEMENT',
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.8,
                          color: _green),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      generatedAt,
                      style: pw.TextStyle(fontSize: 9, color: _muted),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      entries.isEmpty
                          ? 'All time'
                          : 'Since last settlement',
                      style: pw.TextStyle(fontSize: 9, color: _mutedLight),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // ── Entries table ────────────────────────────────────────────────
          if (entries.isNotEmpty) ...[
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 28),
              child: pw.Column(
                children: [
                  // Table header row
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 7),
                    decoration: const pw.BoxDecoration(
                      color: _ink,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Row(
                      children: [
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text('DATE',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: _headingDark)),
                        ),
                        pw.Expanded(
                          flex: 4,
                          child: pw.Text('DESCRIPTION',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: _headingDark)),
                        ),
                        pw.SizedBox(
                          width: 72,
                          child: pw.Text('DEBIT',
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: _headingDark)),
                        ),
                        pw.SizedBox(
                          width: 72,
                          child: pw.Text('CREDIT',
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: _headingDark)),
                        ),
                        pw.SizedBox(
                          width: 80,
                          child: pw.Text('BALANCE',
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: _headingDark)),
                        ),
                        pw.SizedBox(width: 10),
                      ],
                    ),
                  ),
                  // Entry rows with running balance
                  ..._buildEntryRows(entries),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // ── Outstanding total box ────────────────────────────────────────
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(horizontal: 28),
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: outstandingBalance > 0 ? _amberLight : _paper,
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: _border, width: 1),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'TOTAL OUTSTANDING',
                        style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.0,
                            color: _muted),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        outstandingBalance > 0
                            ? 'Amount due to ${shopName}'
                            : 'Account settled — no balance due',
                        style: pw.TextStyle(fontSize: 10, color: _muted),
                      ),
                    ],
                  ),
                ),
                pw.Text(
                  'Rs ${outstandingBalance.toStringAsFixed(0)}',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: outstandingBalance > 0 ? _amber : _greenDark,
                  ),
                ),
              ],
            ),
          ),

          // ── Payment methods QR section ───────────────────────────────────
          if (paymentMethods.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(horizontal: 28),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PAY USING ANY OF THESE METHODS',
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.0,
                        color: _muted),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: paymentMethods
                        .map((m) => _buildPaymentMethodCard(m))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],

          pw.SizedBox(height: 24),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(String shopName) {
    return pw.Container(
      color: _ink,
      padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      child: pw.Row(
        children: [
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
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                shopName,
                style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _onDark),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Khata Statement',
                style: pw.TextStyle(fontSize: 11, color: _headingDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildEntryRows(List<KhataEntry> entries) {
    double runningBalance = 0;
    final widgets = <pw.Widget>[];

    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final isCredit = e.type == KhataEntryType.credit;
      if (isCredit) {
        runningBalance += e.amount;
      } else {
        runningBalance -= e.amount;
      }
      final dt = DateTime.fromMillisecondsSinceEpoch(e.timestamp);
      final dateStr = DateFormat('d MMM yy').format(dt);
      final description = e.note?.isNotEmpty == true
          ? e.note!
          : isCredit
              ? 'Credit given'
              : 'Payment received';

      final isEven = i.isEven;

      widgets.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 7),
          decoration: pw.BoxDecoration(
            color: isEven ? _paper : PdfColors.white,
            border: const pw.Border(
                bottom: pw.BorderSide(
                    color: PdfColor(0.945, 0.925, 0.882), width: 0.5)),
          ),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 10),
              pw.Expanded(
                flex: 3,
                child: pw.Text(
                  dateStr,
                  style: pw.TextStyle(fontSize: 9, color: _muted),
                ),
              ),
              pw.Expanded(
                flex: 4,
                child: pw.Text(
                  description,
                  style: const pw.TextStyle(fontSize: 9),
                  maxLines: 1,
                ),
              ),
              pw.SizedBox(
                width: 72,
                child: pw.Text(
                  isCredit ? 'Rs ${e.amount.toStringAsFixed(0)}' : '',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _red),
                ),
              ),
              pw.SizedBox(
                width: 72,
                child: pw.Text(
                  !isCredit ? 'Rs ${e.amount.toStringAsFixed(0)}' : '',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _greenDark),
                ),
              ),
              pw.SizedBox(
                width: 80,
                child: pw.Text(
                  'Rs ${runningBalance.abs().toStringAsFixed(0)}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: runningBalance > 0 ? _amber : _greenDark,
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  static pw.Widget _buildPaymentMethodCard(ShopPaymentMethod method) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _paper,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _border, width: 1),
      ),
      child: pw.Column(
        children: [
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: method.url,
            width: 90,
            height: 90,
            color: _ink,
            backgroundColor: PdfColors.white,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            method.label,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _ink),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(
      String statementId, int pageNumber, int pagesCount) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(28, 8, 28, 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(height: 0.5, color: _border),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                statementId,
                style: pw.TextStyle(
                    fontSize: 8, letterSpacing: 0.8, color: _muted),
              ),
              pw.Text(
                'Powered by Kamaae',
                style: pw.TextStyle(fontSize: 8, color: _mutedLight),
              ),
              pw.Text(
                'Page $pageNumber of $pagesCount',
                style: pw.TextStyle(fontSize: 8, color: _muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
