import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../database_helper.dart';
import '../models/sale.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

class ReturnScreen extends StatefulWidget {
  final Sale sale;
  final List<SaleTransaction> items;
  final String? customerName;

  const ReturnScreen({
    super.key,
    required this.sale,
    required this.items,
    this.customerName,
  });

  @override
  State<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends State<ReturnScreen> {
  late final Map<int, int> _returnQty;
  bool _isProcessing = false;

  // Sell-type items only (exclude any restock or prior return_ rows)
  late final List<SaleTransaction> _sellItems;

  @override
  void initState() {
    super.initState();
    _sellItems = widget.items
        .where((i) => i.type == TransactionType.sell)
        .toList();
    _returnQty = {for (final i in _sellItems) i.itemId: i.quantity};
  }

  double get _returnTotal {
    double total = 0;
    for (final item in _sellItems) {
      total += item.unitPrice * (_returnQty[item.itemId] ?? 0);
    }
    return total;
  }

  double get _khataReturn {
    if (widget.sale.totalAmount <= 0 || widget.sale.khataAmount <= 0) return 0;
    return (_returnTotal / widget.sale.totalAmount) * widget.sale.khataAmount;
  }

  double get _cashReturn => _returnTotal - _khataReturn;

  int get _itemsBeingReturned =>
      _returnQty.values.where((q) => q > 0).length;

  Future<void> _confirmReturn() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Return',
            style: bricolage(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will:', style: instrument(fontSize: 14)),
            const SizedBox(height: 10),
            _BulletPoint(
                'Restore stock for $_itemsBeingReturned item(s)'),
            if (_cashReturn > 0.01)
              _BulletPoint(
                  'Refund ${formatPkr(_cashReturn)} in cash to customer'),
            if (_khataReturn > 0.01)
              _BulletPoint(
                  'Reduce ${widget.customerName ?? 'customer'}\'s khata by ${formatPkr(_khataReturn)}'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.redLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Symbols.warning,
                      size: 15, color: AppColors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('This cannot be undone.',
                        style: instrument(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.red)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.amber,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Return'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await DatabaseHelper().processReturn(
        saleId: widget.sale.id!,
        customerId: widget.sale.customerId,
        saleTotal: widget.sale.totalAmount,
        saleKhata: widget.sale.khataAmount,
        items: _sellItems,
        returnQuantities: _returnQty,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Return processed — ${formatPkr(_returnTotal)} refund'),
            backgroundColor: AppColors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process return: $e'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Symbols.arrow_back,
                        size: 24, color: AppColors.ink),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Process Return',
                        style: bricolage(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                  Text('Sale #${widget.sale.id}',
                      style: mono(fontSize: 13, color: AppColors.muted)),
                ],
              ),
            ),

            // ── Content ─────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Items card
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
                          Text('Select Items to Return',
                              style: instrument(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.muted)),
                          const SizedBox(height: 14),
                          ..._sellItems.map((item) {
                            final current = _returnQty[item.itemId] ?? 0;
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 7),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(item.itemName,
                                            style: instrument(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${formatPkr(item.unitPrice)} × ${item.quantity} sold',
                                          style: mono(
                                              fontSize: 11,
                                              color: AppColors.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Qty selector
                                  _QtySelector(
                                    value: current,
                                    max: item.quantity,
                                    onChanged: (v) => setState(
                                        () => _returnQty[item.itemId] = v),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 72,
                                    child: Text(
                                      current > 0
                                          ? formatPkr(
                                              item.unitPrice * current)
                                          : '—',
                                      textAlign: TextAlign.end,
                                      style: mono(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: current > 0
                                            ? AppColors.ink
                                            : AppColors.mutedLight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Summary card
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
                          Text('Refund Summary',
                              style: instrument(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.muted)),
                          const SizedBox(height: 12),
                          _SummaryRow(
                            label: 'Return Total',
                            value: formatPkr(_returnTotal),
                            bold: true,
                          ),
                          if (_khataReturn > 0.01) ...[
                            const SizedBox(height: 8),
                            _SummaryRow(
                              label: 'Khata Reduction',
                              value: '− ${formatPkr(_khataReturn)}',
                              valueColor: AppColors.amber,
                            ),
                          ],
                          if (_cashReturn > 0.01) ...[
                            const SizedBox(height: 8),
                            _SummaryRow(
                              label: 'Cash Refund to Customer',
                              value: formatPkr(_cashReturn),
                              valueColor: AppColors.green,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        child: FilledButton.icon(
          onPressed:
              (_isProcessing || _itemsBeingReturned == 0) ? null : _confirmReturn,
          icon: _isProcessing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Symbols.assignment_return),
          label: Text(
            _itemsBeingReturned == 0
                ? 'Select items to return'
                : 'Confirm Return — ${formatPkr(_returnTotal)}',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _itemsBeingReturned == 0
                ? AppColors.mutedLight
                : AppColors.amber,
            minimumSize: const Size(double.infinity, 54),
          ),
        ),
      ),
    );
  }
}

// ── Qty selector ──────────────────────────────────────────────────────────────

class _QtySelector extends StatelessWidget {
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const _QtySelector({
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QtyButton(
            icon: Symbols.remove,
            onTap: value > 0 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: mono(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          _QtyButton(
            icon: Symbols.add,
            onTap: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? AppColors.ink : AppColors.mutedLight,
        ),
      ),
    );
  }
}

// ── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: instrument(
                  fontSize: bold ? 15 : 13,
                  fontWeight:
                      bold ? FontWeight.w600 : FontWeight.w400,
                  color: AppColors.ink)),
        ),
        Text(value,
            style: mono(
                fontSize: bold ? 15 : 13,
                fontWeight:
                    bold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? AppColors.ink)),
      ],
    );
  }
}

// ── Bullet point ──────────────────────────────────────────────────────────────

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(
                  fontSize: 13, color: AppColors.muted)),
          Expanded(
            child: Text(text,
                style: instrument(fontSize: 13, color: AppColors.secondary)),
          ),
        ],
      ),
    );
  }
}
