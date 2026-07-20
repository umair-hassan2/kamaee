import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../database_helper.dart';
import '../models/item.dart';
import '../services/inventory_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/item_photo_widget.dart';

class BulkRestockScreen extends StatefulWidget {
  const BulkRestockScreen({super.key});

  @override
  State<BulkRestockScreen> createState() => _BulkRestockScreenState();
}

class _BulkRestockScreenState extends State<BulkRestockScreen> {
  final _db = DatabaseHelper();
  final _inventoryService = InventoryService();
  final _settingsService = SettingsService();

  List<Item> _items = [];
  final Map<int, TextEditingController> _controllers = {};
  bool _showAll = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final items = await _db.getAllItems();
    for (final item in items) {
      _controllers.putIfAbsent(item.id!, () => TextEditingController());
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  List<Item> get _displayedItems {
    if (_showAll) return _items;
    return _items
        .where((i) => i.quantity <= _settingsService.lowStockThreshold)
        .toList();
  }

  int get _restockCount =>
      _controllers.values.where((c) => (int.tryParse(c.text) ?? 0) > 0).length;

  Future<void> _confirm() async {
    if (_restockCount == 0 || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      int done = 0;
      for (final item in _items) {
        final qty = int.tryParse(_controllers[item.id!]?.text ?? '') ?? 0;
        if (qty > 0) {
          await _inventoryService.restockItem(item, qty);
          done++;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '$done item${done == 1 ? '' : 's'} restocked successfully'),
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _displayedItems;

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bulk Restock',
                            style: bricolage(
                                fontSize: 20, fontWeight: FontWeight.w700)),
                        Text('Enter qty to add per item',
                            style:
                                instrument(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _showAll = !_showAll),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _showAll ? AppColors.ink : AppColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _showAll ? AppColors.ink : AppColors.border,
                        ),
                      ),
                      child: Text(
                        _showAll ? 'All items' : 'Low stock',
                        style: instrument(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              _showAll ? AppColors.paper : AppColors.secondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── List ──────────────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : displayed.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: AppColors.greenLight,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(Symbols.inventory_2,
                                    size: 32, color: AppColors.green),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _showAll
                                    ? 'No items in inventory'
                                    : 'No low stock items',
                                style: instrument(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink),
                              ),
                              if (!_showAll) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _showAll = true),
                                  child: const Text('Show all items'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: displayed.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _RestockRow(
                            item: displayed[i],
                            controller: _controllers[displayed[i].id!]!,
                            lowStockThreshold:
                                _settingsService.lowStockThreshold,
                            onChanged: () => setState(() {}),
                          ),
                        ),
            ),

            // ── Bottom bar ────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, MediaQuery.of(context).padding.bottom + 22),
              decoration: const BoxDecoration(
                color: AppColors.card,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: GestureDetector(
                onTap: (_restockCount == 0 || _isSaving) ? null : _confirm,
                child: AnimatedOpacity(
                  opacity: _restockCount > 0 ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: _isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : Text(
                              _restockCount == 0
                                  ? 'Enter quantities above'
                                  : 'Restock $_restockCount item${_restockCount == 1 ? '' : 's'} →',
                              style: instrument(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Restock row ───────────────────────────────────────────────────────────────

class _RestockRow extends StatelessWidget {
  final Item item;
  final TextEditingController controller;
  final int lowStockThreshold;
  final VoidCallback onChanged;

  const _RestockRow({
    required this.item,
    required this.controller,
    required this.lowStockThreshold,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isOut = item.quantity <= 0;
    final isLow = !isOut && item.quantity <= lowStockThreshold;
    final hasQty = (int.tryParse(controller.text) ?? 0) > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasQty ? AppColors.green : AppColors.border,
          width: hasQty ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.paperDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ItemPhotoWidget(photoPath: item.photoPath),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style:
                      instrument(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      'Stock: ${item.quantity}',
                      style: instrument(fontSize: 12, color: AppColors.muted),
                    ),
                    if (isOut) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.redLight,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text('Out',
                            style: instrument(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.red)),
                      ),
                    ] else if (isLow) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.amberLight,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text('Low',
                            style: instrument(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.amberDark)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 72,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: hasQty ? AppColors.greenLight : AppColors.paperDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasQty ? AppColors.green : AppColors.borderDark,
              ),
            ),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: mono(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: hasQty ? AppColors.greenDark : AppColors.ink,
              ),
              decoration: InputDecoration(
                hintText: '+0',
                hintStyle: mono(fontSize: 13, color: AppColors.mutedLight),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }
}
