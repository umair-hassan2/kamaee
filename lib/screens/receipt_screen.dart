import 'package:flutter/material.dart';
import '../models/sale.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

class ReceiptScreen extends StatelessWidget {
  final Sale sale;
  final List<SaleTransaction> items;
  final String? customerName;

  final String? customerName;

  const ReceiptScreen({
    super.key,
    required this.sale,
    required this.items,
    this.customerName,
  });

  String get _paymentLabel {
    return switch (sale.paymentMethod) {
      PaymentMethod.cash => 'Cash',
      PaymentMethod.khata => 'Khata (Udhaar)',
      PaymentMethod.partial => 'Partial Payment',
    };
  }

  @override
  Widget build(BuildContext context) {
    final saleTime = DateTime.fromMillisecondsSinceEpoch(sale.timestamp);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () {
              // Pop back to root (home) — pop twice since CheckoutScreen
              // was replaced, so we only need to pop CartScreen too
              Navigator.of(context)
                ..pop(true)  // CartScreen sees true → pops itself
                ;
            },
            child: const Text('Done'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Success header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.sell.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: AppColors.sell, size: 40),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sale Recorded',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  if (customerName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        customerName!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  Text(
                    '${_timeString(saleTime)} · ${_paymentLabel}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                ],
              ),
            ),

            // Line items
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Items',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...items.map(
                    (line) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              line.itemName,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Text(
                            '${line.quantity} × ${formatPkr(line.unitPrice)}',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.muted),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 80,
                            child: Text(
                              formatPkr(line.revenue),
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  _ReceiptRow(
                    label: 'Total',
                    value: formatPkr(sale.totalAmount),
                    bold: true,
                  ),
                  if (sale.paidAmount > 0 && sale.paymentMethod != PaymentMethod.cash) ...[
                    const SizedBox(height: 6),
                    _ReceiptRow(
                      label: 'Paid now',
                      value: formatPkr(sale.paidAmount),
                      color: AppColors.sell,
                    ),
                  ],
                  if (sale.khataAmount > 0) ...[
                    const SizedBox(height: 6),
                    _ReceiptRow(
                      label: 'On Khata',
                      value: formatPkr(sale.khataAmount),
                      color: AppColors.warning,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Payment method badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _methodColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _methodColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(_methodIcon, color: _methodColor, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    _paymentLabel,
                    style: TextStyle(
                      color: _methodColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Action buttons
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Back to Home'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _methodColor => switch (sale.paymentMethod) {
        PaymentMethod.cash => AppColors.sell,
        PaymentMethod.khata => AppColors.warning,
        PaymentMethod.partial => AppColors.accent,
      };

  IconData get _methodIcon => switch (sale.paymentMethod) {
        PaymentMethod.cash => Icons.payments_outlined,
        PaymentMethod.khata => Icons.account_balance_wallet_outlined,
        PaymentMethod.partial => Icons.call_split_outlined,
      };

  String _timeString(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 16 : 14,
      color: color,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}
