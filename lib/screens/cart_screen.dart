import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/transaction.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _cartService = CartService();
  List<SaleTransaction> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _cartService.getCartItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  double get _total => _items.fold(0.0, (sum, t) => sum + t.revenue);

  Future<void> _updateQty(SaleTransaction line, int delta) async {
    final newQty = line.quantity + delta;
    if (newQty <= 0) {
      await _cartService.removeItem(line.id!);
    } else {
      await _cartService.updateItemQty(line.id!, newQty);
    }
    await _load();
  }

  Future<void> _clearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear cart?',
            style: bricolage(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text('This will remove all items from the cart.',
            style: instrument(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _cartService.clearCart();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _checkout() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(items: _items, total: _total),
      ),
    );
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
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
                    child: Text('Cart',
                        style: bricolage(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                  if (_items.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '${_items.length} item${_items.length == 1 ? '' : 's'}',
                        style: instrument(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _clearCart,
                      child: const Icon(Symbols.delete,
                          size: 23, color: AppColors.red),
                    ),
                  ],
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────
            if (_loading)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else if (_items.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.greenLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Symbols.shopping_cart,
                            size: 36, color: AppColors.green),
                      ),
                      const SizedBox(height: 16),
                      Text('Cart is empty',
                          style: instrument(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink)),
                      const SizedBox(height: 6),
                      Text('Scan items to add them',
                          style: instrument(
                              fontSize: 14, color: AppColors.muted)),
                    ],
                  ),
                ),
              )
            else ...[
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _CartLineItem(
                    line: _items[i],
                    onIncrement: () => _updateQty(_items[i], 1),
                    onDecrement: () => _updateQty(_items[i], -1),
                  ),
                ),
              ),
              _CartFooter(total: _total, onCheckout: _checkout),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Cart line item ────────────────────────────────────────────────────────────

class _CartLineItem extends StatelessWidget {
  final SaleTransaction line;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CartLineItem({
    required this.line,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.itemName,
                    style: instrument(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${formatPkr(line.unitPrice)} each',
                  style: mono(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: onDecrement,
                child: const Icon(Symbols.remove_circle,
                    size: 24, color: AppColors.green, fill: 1),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 18,
                child: Text(
                  '${line.quantity}',
                  textAlign: TextAlign.center,
                  style: mono(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onIncrement,
                child: const Icon(Symbols.add_circle,
                    size: 24, color: AppColors.green, fill: 1),
              ),
            ],
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: Text(
              formatPkr(line.revenue),
              textAlign: TextAlign.right,
              style: mono(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cart footer ───────────────────────────────────────────────────────────────

class _CartFooter extends StatelessWidget {
  final double total;
  final VoidCallback onCheckout;

  const _CartFooter({required this.total, required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 16, 20, MediaQuery.of(context).padding.bottom + 22,
      ),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total',
                  style: instrument(fontSize: 12, color: AppColors.muted)),
              Text(
                formatPkr(total),
                style: mono(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    letterSpacing: -0.01),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: onCheckout,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Checkout',
                        style: instrument(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(width: 8),
                    const Icon(Symbols.arrow_forward,
                        size: 22, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
