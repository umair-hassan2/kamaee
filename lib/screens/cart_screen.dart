import 'package:flutter/material.dart';
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

  Future<void> _remove(SaleTransaction line) async {
    await _cartService.removeItem(line.id!);
    await _load();
  }

  Future<void> _clearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear cart?'),
        content: const Text('This will remove all items from the cart.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
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
        builder: (_) => CheckoutScreen(
          items: _items,
          total: _total,
        ),
      ),
    );
    if (result == true && mounted) {
      Navigator.pop(context, true); // signal home to refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear cart',
              onPressed: _clearCart,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _EmptyCart()
              : Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _CartLineItem(
                          line: _items[i],
                          onIncrement: () => _updateQty(_items[i], 1),
                          onDecrement: () => _updateQty(_items[i], -1),
                          onRemove: () => _remove(_items[i]),
                        ),
                      ),
                    ),
                    _CartFooter(total: _total, onCheckout: _checkout),
                  ],
                ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 72, color: AppColors.muted),
          SizedBox(height: 16),
          Text(
            'Cart is empty',
            style: TextStyle(fontSize: 18, color: AppColors.muted),
          ),
          SizedBox(height: 8),
          Text(
            'Scan items or browse inventory to add them',
            style: TextStyle(fontSize: 14, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _CartLineItem extends StatelessWidget {
  final SaleTransaction line;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _CartLineItem({
    required this.line,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.itemName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatPkr(line.unitPrice)} each',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                iconSize: 20,
                color: AppColors.primary,
                onPressed: onDecrement,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '${line.quantity}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 20,
                color: AppColors.primary,
                onPressed: onIncrement,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatPkr(line.revenue),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.sell,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.close, size: 16, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartFooter extends StatelessWidget {
  final double total;
  final VoidCallback onCheckout;

  const _CartFooter({required this.total, required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Total', style: TextStyle(color: AppColors.muted, fontSize: 13)),
              Text(
                formatPkr(total),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: FilledButton.icon(
              onPressed: onCheckout,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Checkout'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.sell,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
