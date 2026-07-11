import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/item.dart';
import '../screens/edit_item_screen.dart';
import '../services/cart_service.dart';
import '../services/inventory_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/item_photo_widget.dart';

enum ItemActionMode { sell, restock }

class ItemActionSheet extends StatefulWidget {
  final Item item;
  final VoidCallback onDone;
  final VoidCallback onCancel;
  /// When true, shows "Add to Cart" alongside "Sell" for multi-item sessions.
  final bool showAddToCart;

  const ItemActionSheet({
    super.key,
    required this.item,
    required this.onDone,
    required this.onCancel,
    this.showAddToCart = false,
  });

  @override
  State<ItemActionSheet> createState() => _ItemActionSheetState();
}

class _ItemActionSheetState extends State<ItemActionSheet> {
  final _inventoryService = InventoryService();
  final _settingsService = SettingsService();
  final _cartService = CartService();
  final _quantityController = TextEditingController(text: '1');
  ItemActionMode _mode = ItemActionMode.sell;
  int _quantity = 1;
  bool _isLoading = false;

  Item get item => widget.item;

  int get _maxSellQuantity => item.quantity.clamp(0, 9999);

  bool get _canSell => _maxSellQuantity > 0;

  @override
  void initState() {
    super.initState();
    if (!_canSell) {
      _mode = ItemActionMode.restock;
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _updateQuantity(int value) {
    final max = _mode == ItemActionMode.sell ? _maxSellQuantity : 9999;
    final clamped = value.clamp(1, max);
    setState(() {
      _quantity = clamped;
      _quantityController.text = '$clamped';
    });
  }

  void _setMode(ItemActionMode mode) {
    setState(() {
      _mode = mode;
      _quantity = 1;
      _quantityController.text = '1';
      if (_mode == ItemActionMode.sell && _quantity > _maxSellQuantity) {
        _updateQuantity(_maxSellQuantity);
      }
    });
  }

  void _decrement() {
    if (_quantity > 1) {
      _updateQuantity(_quantity - 1);
    }
  }

  void _increment() {
    final max = _mode == ItemActionMode.sell ? _maxSellQuantity : 9999;
    if (_quantity < max) {
      _updateQuantity(_quantity + 1);
    }
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      if (_mode == ItemActionMode.sell) {
        await _inventoryService.sellItem(item, _quantity);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sold $_quantity × "${item.name}" '
              '(${formatPkr(item.sellingPrice * _quantity)})',
            ),
            backgroundColor: AppColors.sell,
          ),
        );
      } else {
        await _inventoryService.restockItem(item, _quantity);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restocked $_quantity × "${item.name}"'),
            backgroundColor: AppColors.restock,
          ),
        );
      }
      widget.onDone();
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

  Future<void> _addToCart() async {
    if (_isLoading || _mode != ItemActionMode.sell) return;
    setState(() => _isLoading = true);
    try {
      await _cartService.addItem(item, _quantity);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $_quantity × "${item.name}" to cart'),
          backgroundColor: AppColors.primary,
        ),
      );
      widget.onDone();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditItemScreen(item: item),
      ),
    );
    if (updated == true && mounted) {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final threshold = _settingsService.lowStockThreshold;
    final stockStatus = _stockLabel(item.quantity, threshold);
    final total = _mode == ItemActionMode.sell
        ? item.sellingPrice * _quantity
        : item.purchasePrice * _quantity;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ItemPhotoWidget(
                photoPath: item.photoPath,
                size: 52,
                borderRadius: 12,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.barcode,
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _StockBadge(label: stockStatus.label, color: stockStatus.color),
              IconButton(
                onPressed: _isLoading ? null : _openEdit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit item',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                _InfoChip(
                  label: 'In Stock',
                  value: '${item.quantity}',
                  color: stockStatus.color,
                ),
                const SizedBox(width: 12),
                _InfoChip(
                  label: 'Sell Price',
                  value: formatPkr(item.sellingPrice),
                  color: AppColors.sell,
                ),
                const SizedBox(width: 12),
                _InfoChip(
                  label: 'Cost',
                  value: formatPkr(item.purchasePrice),
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SegmentedButton<ItemActionMode>(
            segments: const [
              ButtonSegment(
                value: ItemActionMode.sell,
                label: Text('Sell'),
                icon: Icon(Icons.point_of_sale, size: 18),
              ),
              ButtonSegment(
                value: ItemActionMode.restock,
                label: Text('Restock'),
                icon: Icon(Icons.add_box_outlined, size: 18),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) => _setMode(selection.first),
          ),
          const SizedBox(height: 20),
          Text(
            'Quantity',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _QtyButton(
                icon: Icons.remove,
                onPressed: _quantity > 1 ? _decrement : null,
              ),
              Expanded(
                child: TextField(
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  controller: _quantityController,
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    if (parsed == null || parsed < 1) return;
                    final max =
                        _mode == ItemActionMode.sell ? _maxSellQuantity : 9999;
                    setState(() => _quantity = parsed.clamp(1, max));
                  },
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              _QtyButton(
                icon: Icons.add,
                onPressed: () {
                  final max =
                      _mode == ItemActionMode.sell ? _maxSellQuantity : 9999;
                  if (_quantity < max) _increment();
                },
              ),
            ],
          ),
          if (_mode == ItemActionMode.sell && !_canSell) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppColors.danger, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Out of stock. Switch to Restock to add more.',
                      style: TextStyle(color: AppColors.danger, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _mode == ItemActionMode.sell ? 'Total sale' : 'Restock cost',
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              Text(
                formatPkr(total),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Primary action row
          if (widget.showAddToCart && _mode == ItemActionMode.sell && _canSell) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _submit,
                    icon: const Icon(Icons.bolt, size: 18),
                    label: const Text('Quick Sell'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.sell,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _addToCart,
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('Add to Cart'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            FilledButton(
              onPressed:
                  _isLoading || (_mode == ItemActionMode.sell && !_canSell)
                      ? null
                      : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: _mode == ItemActionMode.sell
                    ? AppColors.sell
                    : AppColors.restock,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_mode == ItemActionMode.sell
                      ? 'Sell $_quantity'
                      : 'Restock $_quantity'),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _isLoading ? null : widget.onCancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  ({String label, Color color}) _stockLabel(int qty, int threshold) {
    if (qty <= 0) return (label: 'Out', color: AppColors.danger);
    if (qty <= threshold) return (label: 'Low', color: AppColors.warning);
    return (label: 'OK', color: AppColors.sell);
  }
}

class _StockBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StockBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _QtyButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        foregroundColor: AppColors.primary,
      ),
    );
  }
}

Future<void> showItemActionSheet({
  required BuildContext context,
  required Item item,
  required VoidCallback onDone,
  required VoidCallback onCancel,
  bool showAddToCart = false,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ItemActionSheet(
      item: item,
      onDone: onDone,
      onCancel: onCancel,
      showAddToCart: showAddToCart,
    ),
  );
}
