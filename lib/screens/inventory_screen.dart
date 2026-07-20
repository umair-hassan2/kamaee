import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../database_helper.dart';
import '../models/item.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/item_action_sheet.dart';
import '../widgets/item_photo_widget.dart';
import 'bulk_restock_screen.dart';

class InventoryScreen extends StatefulWidget {
  final int refreshKey;

  const InventoryScreen({super.key, this.refreshKey = 0});

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
  void didUpdateWidget(InventoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      _loadItems();
    }
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
          .where((item) =>
              item.name.toLowerCase().contains(query) ||
              item.barcode.toLowerCase().contains(query))
          .toList();
    }
    result.sort((a, b) {
      switch (_sortBy) {
        case 'quantity':
          return a.quantity.compareTo(b.quantity);
        case 'price':
          return b.sellingPrice.compareTo(a.sellingPrice);
        case 'margin':
          double marginOf(Item i) => i.sellingPrice > 0
              ? (i.sellingPrice - i.purchasePrice) / i.sellingPrice
              : 0;
          return marginOf(b).compareTo(marginOf(a));
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
      showAddToCart: true,
      onDone: () {
        Navigator.pop(context);
        _loadItems();
      },
      onCancel: () => Navigator.pop(context),
    );
  }

  int get _totalUnits => _items.fold(0, (sum, item) => sum + item.quantity);
  int get _lowStockCount =>
      _items.where((i) => _settingsService.isLowStock(i.quantity)).length;
  int get _outOfStockCount =>
      _items.where((i) => _settingsService.isOutOfStock(i.quantity)).length;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: RefreshIndicator(
        onRefresh: _loadItems,
        color: AppColors.green,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, topPadding + 14, 20, 0),
                child: Column(
                  children: [
                    // ── Header ────────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Inventory',
                                  style: bricolage(
                                      fontSize: 28, fontWeight: FontWeight.w700)),
                              Text(
                                '${_items.length} products · $_totalUnits units',
                                style: instrument(
                                    fontSize: 13, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const BulkRestockScreen()),
                            );
                            _loadItems();
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.paperDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(Symbols.add_box,
                                size: 20, color: AppColors.ink),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _navigateToAddItem(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.ink,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Symbols.add,
                                size: 22, color: AppColors.paper),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ── Stats grid ───────────────────────────────────────
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 2.5,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      children: [
                        _StatTile(
                          icon: Symbols.category,
                          iconBg: AppColors.greenLight,
                          iconColor: AppColors.green,
                          value: '${_items.length}',
                          label: 'Items',
                        ),
                        _StatTile(
                          icon: Symbols.inventory_2,
                          iconBg: AppColors.blueLight,
                          iconColor: AppColors.blue,
                          value: '$_totalUnits',
                          label: 'Units',
                        ),
                        _StatTile(
                          icon: Symbols.warning,
                          iconBg: AppColors.amberLight,
                          iconColor: AppColors.amber,
                          value: '$_lowStockCount',
                          label: 'Low stock',
                        ),
                        _StatTile(
                          icon: Symbols.remove_shopping_cart,
                          iconBg: AppColors.redLight,
                          iconColor: AppColors.red,
                          value: '$_outOfStockCount',
                          label: 'Out',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Search ───────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Symbols.search,
                              size: 20, color: AppColors.mutedLight),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: instrument(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Search by name or barcode…',
                                hintStyle: instrument(
                                    fontSize: 14, color: AppColors.mutedLight),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: _searchController.clear,
                              child: const Icon(Symbols.close,
                                  size: 18, color: AppColors.muted),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Sort chips ───────────────────────────────────────
                    Row(
                      children: [
                        _SortChip(
                            label: 'Name',
                            selected: _sortBy == 'name',
                            onTap: () {
                              setState(() => _sortBy = 'name');
                              _filterItems();
                            }),
                        const SizedBox(width: 8),
                        _SortChip(
                            label: 'Stock',
                            selected: _sortBy == 'quantity',
                            onTap: () {
                              setState(() => _sortBy = 'quantity');
                              _filterItems();
                            }),
                        const SizedBox(width: 8),
                        _SortChip(
                            label: 'Price',
                            selected: _sortBy == 'price',
                            onTap: () {
                              setState(() => _sortBy = 'price');
                              _filterItems();
                            }),
                        const SizedBox(width: 8),
                        _SortChip(
                            label: 'Margin',
                            selected: _sortBy == 'margin',
                            onTap: () {
                              setState(() => _sortBy = 'margin');
                              _filterItems();
                            }),
                      ],
                    ),
                    const SizedBox(height: 14),
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
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.greenLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Symbols.inventory_2,
                            size: 36, color: AppColors.green),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _items.isEmpty
                            ? 'No items yet'
                            : 'No items match your search',
                        style: instrument(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink),
                      ),
                      if (_items.isEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Scan a barcode to add your first item',
                          style: instrument(fontSize: 13, color: AppColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
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
      ),
    );
  }

  void _navigateToAddItem(BuildContext context) {
    // Scan a barcode to add — trigger scanner from here if needed
    // For now, tap the + to show a message; actual add happens via barcode scanner
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Use barcode scanner to add new items')),
    );
  }
}

// ── Stat tile ─────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: iconColor),
          ),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                  style: mono(
                      fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.ink)),
              Text(label,
                  style: instrument(fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Margin badge ──────────────────────────────────────────────────────────────

class _MarginBadge extends StatelessWidget {
  final Item item;
  const _MarginBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.sellingPrice <= 0) {
      return Text('—', style: instrument(fontSize: 10.5, color: AppColors.mutedLight));
    }
    final pct =
        (item.sellingPrice - item.purchasePrice) / item.sellingPrice * 100;
    final Color bg;
    final Color text;
    if (pct >= 25) {
      bg = AppColors.greenLight;
      text = AppColors.greenDark;
    } else if (pct >= 10) {
      bg = AppColors.amberLight;
      text = AppColors.amberDark;
    } else {
      bg = AppColors.redLight;
      text = AppColors.red;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        '${pct.toStringAsFixed(0)}%',
        style: instrument(
            fontSize: 10.5, fontWeight: FontWeight.w600, color: text),
      ),
    );
  }
}

// ── Sort chip ─────────────────────────────────────────────────────────────────

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppColors.ink : AppColors.border),
        ),
        child: Text(
          label,
          style: instrument(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.paper : AppColors.secondary,
          ),
        ),
      ),
    );
  }
}

// ── Inventory item card ───────────────────────────────────────────────────────

class _InventoryItemCard extends StatelessWidget {
  final Item item;
  final int lowStockThreshold;
  final VoidCallback onTap;

  const _InventoryItemCard({
    required this.item,
    required this.lowStockThreshold,
    required this.onTap,
  });

  ({Color bg, Color text, String label}) get _stockStatus {
    if (item.quantity <= 0) {
      return (
        bg: AppColors.redLight,
        text: AppColors.red,
        label: 'Out of stock'
      );
    }
    if (item.quantity <= lowStockThreshold) {
      return (
        bg: AppColors.amberLight,
        text: AppColors.amberDark,
        label: 'Low stock'
      );
    }
    return (
      bg: AppColors.greenLight,
      text: AppColors.greenDark,
      label: 'In stock'
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _stockStatus;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.paperDark,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: ItemPhotoWidget(photoPath: item.photoPath),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: instrument(
                          fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.barcode,
                      style: mono(fontSize: 11.5, color: AppColors.muted),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: s.bg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(s.label,
                              style: instrument(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: s.text)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Qty ${item.quantity}',
                          style:
                              instrument(fontSize: 11.5, color: AppColors.muted),
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
                    style: mono(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green),
                  ),
                  const SizedBox(height: 4),
                  _MarginBadge(item: item),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
