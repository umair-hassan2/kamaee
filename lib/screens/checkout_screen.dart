import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sale.dart';
import '../models/transaction.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'receipt_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<SaleTransaction> items;
  final double total;

  const CheckoutScreen({
    super.key,
    required this.items,
    required this.total,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _cartService = CartService();
  PaymentMethod _method = PaymentMethod.cash;
  final _paidController = TextEditingController();
  bool _isLoading = false;

  double get _paid {
    if (_method == PaymentMethod.cash) return widget.total;
    if (_method == PaymentMethod.khata) return 0;
    return double.tryParse(_paidController.text) ?? 0;
  }

  double get _khata => (widget.total - _paid).clamp(0, widget.total);

  @override
  void dispose() {
    _paidController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final sale = await _cartService.completeSale(
        paymentMethod: _method,
        paidAmount: _paid,
      );
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptScreen(
            sale: sale,
            items: widget.items,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('StateError: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Order summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Summary',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                ),
                const SizedBox(height: 12),
                ...widget.items.map(
                  (line) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${line.itemName} × ${line.quantity}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          formatPkr(line.revenue),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Text(
                      formatPkr(widget.total),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Payment Method',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),

          _PaymentOption(
            label: 'Cash',
            subtitle: 'Full amount paid now',
            icon: Icons.payments_outlined,
            color: AppColors.sell,
            selected: _method == PaymentMethod.cash,
            onTap: () => setState(() {
              _method = PaymentMethod.cash;
            }),
          ),
          const SizedBox(height: 10),
          _PaymentOption(
            label: 'Khata (Udhaar)',
            subtitle: 'Full amount on credit',
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.warning,
            selected: _method == PaymentMethod.khata,
            onTap: () => setState(() {
              _method = PaymentMethod.khata;
            }),
          ),
          const SizedBox(height: 10),
          _PaymentOption(
            label: 'Partial Payment',
            subtitle: 'Some cash now, rest on credit',
            icon: Icons.call_split_outlined,
            color: AppColors.accent,
            selected: _method == PaymentMethod.partial,
            onTap: () => setState(() {
              _method = PaymentMethod.partial;
            }),
          ),

          if (_method == PaymentMethod.partial) ...[
            const SizedBox(height: 20),
            Text(
              'Amount Paid Now',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _paidController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '0.00',
                prefixText: 'PKR ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_paidController.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Khata amount: ${formatPkr(_khata)}',
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

          const SizedBox(height: 32),

          FilledButton(
            onPressed: _isLoading ? null : _confirm,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sell,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _method == PaymentMethod.cash
                        ? 'Confirm Sale • ${formatPkr(widget.total)}'
                        : _method == PaymentMethod.khata
                            ? 'Record on Khata • ${formatPkr(widget.total)}'
                            : 'Confirm • ${formatPkr(_paid)} now + ${formatPkr(_khata)} khata',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: selected ? color : null,
                      )),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: color, size: 22)
            else
              Icon(Icons.circle_outlined, color: Colors.grey.shade300, size: 22),
          ],
        ),
      ),
    );
  }
}
