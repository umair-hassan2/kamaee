import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/item.dart';
import '../services/inventory_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/item_photo_widget.dart';

class RestockEntry {
  final Item item;
  int qty;
  RestockEntry({required this.item, this.qty = 1});
}

class BulkRestockConfirmScreen extends StatefulWidget {
  final List<RestockEntry> entries;

  const BulkRestockConfirmScreen({super.key, required this.entries});

  @override
  State<BulkRestockConfirmScreen> createState() =>
      _BulkRestockConfirmScreenState();
}

class _BulkRestockConfirmScreenState extends State<BulkRestockConfirmScreen> {
  final _inventoryService = InventoryService();
  late final List<RestockEntry> _entries;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _entries = List.from(widget.entries);
  }

  void _updateQty(int index, int delta) {
    final newQty = (_entries[index].qty + delta).clamp(1, 9999);
    setState(() => _entries[index].qty = newQty);
  }

  void _setQty(int index, String value) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > 0) {
      setState(() => _entries[index].qty = parsed.clamp(1, 9999));
    }
  }

  Future<void> _confirm() async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);
    try {
      for (final entry in _entries) {
        await _inventoryService.restockItem(entry.item, entry.qty);
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  int get _totalUnits =>
      _entries.fold(0, (sum, e) => sum + e.qty);

  double get _totalCost =>
      _entries.fold(0.0, (sum, e) => sum + e.item.purchasePrice * e.qty);

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
                    onTap: () => Navigator.pop(context, false),
                    child: const Icon(Symbols.arrow_back,
                        size: 24, color: AppColors.ink),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Review Restock',
                            style: bricolage(
                                fontSize: 20, fontWeight: FontWeight.w700)),
                        Text(
                          '${_entries.length} item${_entries.length == 1 ? '' : 's'} · $_totalUnits units',
                          style: instrument(
                              fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── List ────────────────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: _entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _ConfirmRow(
                  entry: _entries[i],
                  onIncrement: () => _updateQty(i, 1),
                  onDecrement: () => _updateQty(i, -1),
                  onQtyChanged: (v) => _setQty(i, v),
                ),
              ),
            ),

            // ── Bottom summary + confirm ─────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, MediaQuery.of(context).padding.bottom + 22),
              decoration: const BoxDecoration(
                color: AppColors.card,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('Total cost',
                          style: instrument(
                              fontSize: 13, color: AppColors.muted)),
                      const Spacer(),
                      Text(
                        formatPkr(_totalCost),
                        style: mono(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _isConfirming ? null : _confirm,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: _isConfirming
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : Text(
                                'Confirm Restock →',
                                style: instrument(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Confirm row ───────────────────────────────────────────────────────────────

class _ConfirmRow extends StatefulWidget {
  final RestockEntry entry;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ValueChanged<String> onQtyChanged;

  const _ConfirmRow({
    required this.entry,
    required this.onIncrement,
    required this.onDecrement,
    required this.onQtyChanged,
  });

  @override
  State<_ConfirmRow> createState() => _ConfirmRowState();
}

class _ConfirmRowState extends State<_ConfirmRow> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.entry.qty}');
  }

  @override
  void didUpdateWidget(_ConfirmRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.qty != widget.entry.qty) {
      final newText = '${widget.entry.qty}';
      if (_controller.text != newText) {
        _controller.text = newText;
        _controller.selection =
            TextSelection.collapsed(offset: newText.length);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.entry.item;
    final subtotal = item.purchasePrice * widget.entry.qty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
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
                  style: instrument(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Stock: ${item.quantity} → ${item.quantity + widget.entry.qty}',
                      style: instrument(fontSize: 11.5, color: AppColors.muted),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatPkr(subtotal),
                      style: mono(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Qty stepper
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepBtn(
                icon: Symbols.remove,
                onTap: widget.entry.qty > 1 ? widget.onDecrement : null,
              ),
              Container(
                width: 44,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: mono(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                  ),
                  onChanged: widget.onQtyChanged,
                ),
              ),
              _StepBtn(icon: Symbols.add, onTap: widget.onIncrement),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: enabled ? AppColors.paperDark : AppColors.paper,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Icon(icon,
            size: 16,
            color: enabled ? AppColors.ink : AppColors.mutedLight),
      ),
    );
  }
}
