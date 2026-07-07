import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/item.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/item_action_sheet.dart';
import '../widgets/item_photo_widget.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _db = DatabaseHelper();
  final _settingsService = SettingsService();
  final _searchController = TextEditingController();
  List<Item> _items = [];
  List<Item> _filtered = [];
  bool _isLoading = true;
  String _sortBy = 'name';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final items = await _db.getAllItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
    _filterItems();
  }

  void _onSearchChanged() {
    _filterItems();
    setState(() {});
  }

  void _filterItems() {
    final query = _searchController.text.trim().toLowerCase();
    var result = List<Item>.from(_items);

    if (query.isNotEmpty) {
      result = result
          .where(
            (item) =>
                item.name.toLowerCase().contains(query) ||
                item.barcode.toLowerCase().contains(query),
          )
          .toList();
    }

    result.sort((a, b) {
      switch (_sortBy) {
        case 'quantity':
          return a.quantity.compareTo(b.quantity);
        case 'price':
          return b.sellingPrice.compareTo(a.sellingPrice);
        case 'name':
        default:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    setState(() => _filtered = result);
  }

  Future<void> _openItemActions(Item item) async {
    await showItemActionSheet(
      context: context,
      item: item,
      onDone: () {
        Navigator.pop(context);
        _loadItems();
      },
      onCancel: () => Navigator.pop(context),
    );
  }

  int get _totalUnits => _items.fold(0, (sum, item) => sum + item.quantity);

  int get _lowStockCount => _items
      .where((item) => _settingsService.isLowStock(item.quantity))
      .length;

  int get _outOfStockCount =>
      _items.where((item) => _settingsService.isOutOfStock(item.quantity)).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Inventory'),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: 'Items',
                          value: '${_items.length}',
                          icon: Icons.category_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryCard(
                          label: 'Units',
                          value: '$_totalUnits',
                          icon: Icons.inventory_outlined,
                          color: AppColors.restock,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: 'Low Stock',
                          value: '$_lowStockCount',
                          icon: Icons.warning_amber_rounded,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryCard(
                          label: 'Out of Stock',
                          value: '$_outOfStockCount',
                          icon: Icons.remove_shopping_cart_outlined,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name or barcode...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Sort by',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _SortChip(
                                label: 'Name',
                                selected: _sortBy == 'name',
                                onTap: () {
                                  setState(() => _sortBy = 'name');
                                  _filterItems();
                                },
                              ),
                              _SortChip(
                                label: 'Stock',
                                selected: _sortBy == 'quantity',
                                onTap: () {
                                  setState(() => _sortBy = 'quantity');
                                  _filterItems();
                                },
                              ),
                              _SortChip(
                                label: 'Price',
                                selected: _sortBy == 'price',
                                onTap: () {
                                  setState(() => _sortBy = 'price');
                                  _filterItems();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      _items.isEmpty
                          ? 'No items yet'
                          : 'No items match your search',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (_items.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Scan a barcode to add your first item',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.separated(
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _filtered[index];
                  return _InventoryItemCard(
                    item: item,
                    lowStockThreshold: _settingsService.lowStockThreshold,
                    onTap: () => _openItemActions(item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted)),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        checkmarkColor: AppColors.primary,
      ),
    );
  }
}

class _InventoryItemCard extends StatelessWidget {
  final Item item;
  final int lowStockThreshold;
  final VoidCallback onTap;

  const _InventoryItemCard({
    required this.item,
    required this.lowStockThreshold,
    required this.onTap,
  });

  Color get _stockColor {
    if (item.quantity <= 0) return AppColors.danger;
    if (item.quantity <= lowStockThreshold) return AppColors.warning;
    return AppColors.sell;
  }

  String get _stockLabel {
    if (item.quantity <= 0) return 'Out of stock';
    if (item.quantity <= lowStockThreshold) return 'Low stock';
    return 'In stock';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              ItemPhotoWidget(photoPath: item.photoPath),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.barcode,
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _stockColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _stockLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _stockColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Qty: ${item.quantity}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatPkr(item.sellingPrice),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.sell,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'tap to manage',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
