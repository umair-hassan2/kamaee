import 'dart:io';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/sale.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/receipt_pdf_generator.dart';
import '../services/settings_service.dart';

class ReceiptScreen extends StatefulWidget {
  final Sale sale;
  final List<SaleTransaction> items;
  final String? customerName;

  const ReceiptScreen({
    super.key,
    required this.sale,
    required this.items,
    this.customerName,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  bool _sharing = false;

  String get _paymentLabel => switch (widget.sale.paymentMethod) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.khata => 'Khata (Udhaar)',
        PaymentMethod.partial => 'Partial Payment',
      };

  String _timeString(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  Future<void> _shareOnWhatsApp() async {
    setState(() => _sharing = true);
    try {
      final shopName = SettingsService().settings.shopName;
      final pdfBytes = await ReceiptPdfGenerator.generate(
        sale: widget.sale,
        items: widget.items,
        customerName: widget.customerName,
        shopName: shopName.isNotEmpty ? shopName : 'Kamaae',
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/receipt_${widget.sale.id}.pdf');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        text: widget.customerName != null
            ? 'Bill for ${widget.customerName}'
            : 'Your bill',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  ({Color bg, Color border, Color icon, IconData iconData}) get _methodStyle =>
      switch (widget.sale.paymentMethod) {
        PaymentMethod.cash => (
            bg: AppColors.greenLight,
            border: const Color(0xFFC7E4D5),
            icon: AppColors.green,
            iconData: Symbols.payments,
          ),
        PaymentMethod.khata => (
            bg: AppColors.amberLight,
            border: const Color(0xFFEAD6AE),
            icon: AppColors.amber,
            iconData: Symbols.account_balance_wallet,
          ),
        PaymentMethod.partial => (
            bg: AppColors.tealLight,
            border: const Color(0xFFC3E0E3),
            icon: AppColors.teal,
            iconData: Symbols.call_split,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final saleTime =
        DateTime.fromMillisecondsSinceEpoch(widget.sale.timestamp);
    final ms = _methodStyle;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Receipt',
                        style: bricolage(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                  if (_sharing)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    GestureDetector(
                      onTap: _shareOnWhatsApp,
                      child: const Icon(Symbols.ios_share,
                          size: 23, color: AppColors.muted),
                    ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    child: Text('Done',
                        style: instrument(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.green)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // ── Success header ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              color: AppColors.greenLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Symbols.check,
                                color: AppColors.green, size: 40),
                          ),
                          const SizedBox(height: 14),
                          Text('Sale Recorded',
                              style: bricolage(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700)),
                          if (widget.customerName != null) ...[
                            const SizedBox(height: 4),
                            Text(widget.customerName!,
                                style: instrument(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            '${_timeString(saleTime)} · $_paymentLabel',
                            style: mono(
                                fontSize: 12.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),

                    // ── Items ─────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ITEMS',
                            style: instrument(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...widget.items.map((line) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4.5),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(line.itemName,
                                          style: instrument(fontSize: 14)),
                                    ),
                                    Text(
                                      '${line.quantity} × ${formatPkr(line.unitPrice)}',
                                      style: mono(
                                          fontSize: 12.5,
                                          color: AppColors.muted),
                                    ),
                                    const SizedBox(width: 14),
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        formatPkr(line.revenue),
                                        textAlign: TextAlign.right,
                                        style: mono(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 12),
                          const Divider(color: AppColors.border, height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text('Total',
                                    style: instrument(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                              ),
                              Text(
                                formatPkr(widget.sale.totalAmount),
                                style: mono(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          if (widget.sale.paidAmount > 0 &&
                              widget.sale.paymentMethod !=
                                  PaymentMethod.cash) ...[
                            const SizedBox(height: 7),
                            _ReceiptSplitRow(
                              label: 'Paid now',
                              value: formatPkr(widget.sale.paidAmount),
                              color: AppColors.greenDark,
                            ),
                          ],
                          if (widget.sale.khataAmount > 0) ...[
                            const SizedBox(height: 5),
                            _ReceiptSplitRow(
                              label: 'On Khata',
                              value: formatPkr(widget.sale.khataAmount),
                              color: AppColors.amber,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Payment method badge ──────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 13),
                      decoration: BoxDecoration(
                        color: ms.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ms.border),
                      ),
                      child: Row(
                        children: [
                          Icon(ms.iconData, color: ms.icon, size: 20),
                          const SizedBox(width: 10),
                          Text(_paymentLabel,
                              style: instrument(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: ms.icon)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Share WhatsApp ────────────────────────────────────
                    GestureDetector(
                      onTap: _sharing ? null : _shareOnWhatsApp,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFF4FB36A), width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _sharing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Symbols.share,
                                    size: 20,
                                    color: Color(0xFF1E9E48)),
                            const SizedBox(width: 9),
                            Text('Share Bill via WhatsApp',
                                style: instrument(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1E7A3C))),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Back to home ──────────────────────────────────────
                    GestureDetector(
                      onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Symbols.home,
                                size: 20, color: Colors.white),
                            const SizedBox(width: 9),
                            Text('Back to Home',
                                style: instrument(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Receipt split row ─────────────────────────────────────────────────────────

class _ReceiptSplitRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ReceiptSplitRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label, style: instrument(fontSize: 14, color: color))),
        Text(value,
            style: mono(
                fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
