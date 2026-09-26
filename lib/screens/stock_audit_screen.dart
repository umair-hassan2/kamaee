import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../database_helper.dart';
import '../models/item.dart';
import '../models/stock_count.dart';
import '../services/stock_count_service.dart';
import '../theme/app_theme.dart';

class StockAuditScreen extends StatefulWidget {
  const StockAuditScreen({super.key});

  @override
  State<StockAuditScreen> createState() => _StockAuditScreenState();
}

class _StockAuditScreenState extends State<StockAuditScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Stock Audit'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Count Now'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_CountNowTab(), _HistoryTab()],
      ),
    );
  }
}

// ── Count Now ─────────────────────────────────────────────────────────────────

class _CountNowTab extends StatefulWidget {
  const _CountNowTab();

  @override
  State<_CountNowTab> createState() => _CountNowTabState();
}

class _CountNowTabState extends State<_CountNowTab> {
  final _service = StockCountService();
  final _db = DatabaseHelper();
  final _searchController = TextEditingController();
  final _fieldControllers = <int, TextEditingController>{};

  List<Item> _items = [];
  List<StockCount> _lastResult = [];
  String _search = '';
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _service.pendingCounts.addListener(_onPendingChanged);
  }

  @override
  void dispose() {
    _service.pendingCounts.removeListener(_onPendingChanged);
    _searchController.dispose();
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onPendingChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadItems() async {
    final items = await _db.getAllItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  TextEditingController _controllerFor(Item item) {
    return _fieldControllers.putIfAbsent(item.id!, () {
      final pending = _service.pendingCounts.value[item.id!];
      return TextEditingController(text: pending?.toString() ?? '');
    });
  }

  void _onCountChanged(Item item, String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      _service.removePendingCount(item.id!);
      return;
    }
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 0) return;
    _service.setPendingCount(item.id!, parsed);
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      final recorded = await _service.submitPendingCounts();
      if (!mounted) return;
      for (final controller in _fieldControllers.values) {
        controller.clear();
      }
      setState(() {
        _lastResult = recorded;
        _isSubmitting = false;
      });
      await _loadItems();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = 'Could not save your count. Your entries are still '
            'here — tap Submit Count to try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const _EmptyState(
        icon: Symbols.inventory_2,
        title: 'No items to count',
        message: 'Add items to your inventory first, then come back to '
            'count what is on the shelf.',
      );
    }

    final pending = _service.pendingCounts.value;
    final query = _search.toLowerCase();
    final matching = _items
        .where((i) => query.isEmpty || i.name.toLowerCase().contains(query))
        .toList();
    final counting =
        matching.where((i) => pending.containsKey(i.id)).toList();
    final remaining =
        matching.where((i) => !pending.containsKey(i.id)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value),
            style: instrument(fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Search items by name',
              prefixIcon: Icon(Symbols.search, size: 20),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              if (_lastResult.isNotEmpty) ...[
                _ResultSummary(counts: _lastResult),
                const SizedBox(height: 18),
              ],
              if (counting.isNotEmpty) ...[
                const _SectionLabel('Counting now'),
                const SizedBox(height: 8),
                ...counting.map(_buildRow),
                const SizedBox(height: 18),
              ],
              if (remaining.isNotEmpty) ...[
                _SectionLabel(
                  counting.isEmpty ? 'All items' : 'Not counted yet',
                ),
                const SizedBox(height: 8),
                ...remaining.map(_buildRow),
              ],
              if (matching.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No items match "$_search"',
                      style: instrument(fontSize: 14, color: AppColors.muted),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _SubmitBar(
          pendingCount: pending.length,
          isSubmitting: _isSubmitting,
          error: _submitError,
          onSubmit: _submit,
        ),
      ],
    );
  }

  Widget _buildRow(Item item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: instrument(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'App Count: ${item.quantity}',
                    style: instrument(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 92,
              child: TextField(
                controller: _controllerFor(item),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: mono(fontSize: 15, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  labelText: 'Your Count',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                onChanged: (value) => _onCountChanged(item, value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  final int pendingCount;
  final bool isSubmitting;
  final String? error;
  final VoidCallback onSubmit;

  const _SubmitBar({
    required this.pendingCount,
    required this.isSubmitting,
    required this.error,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final canSubmit = pendingCount > 0 && !isSubmitting;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Symbols.error, size: 18, color: AppColors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: instrument(fontSize: 12, color: AppColors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          FilledButton(
            onPressed: canSubmit ? onSubmit : null,
            child: isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(pendingCount > 0
                    ? 'Submit Count ($pendingCount)'
                    : 'Submit Count'),
          ),
          if (pendingCount == 0) ...[
            const SizedBox(height: 6),
            Text(
              'Count at least one item to submit',
              textAlign: TextAlign.center,
              style: instrument(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultSummary extends StatelessWidget {
  final List<StockCount> counts;
  const _ResultSummary({required this.counts});

  @override
  Widget build(BuildContext context) {
    final short = counts.where((c) => c.variance < 0).length;
    final balanced = counts.where((c) => c.variance == 0).length;
    final over = counts.where((c) => c.variance > 0).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: short > 0 ? AppColors.red : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$short short, $balanced balanced, $over over',
            style: bricolage(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...counts.map(
            (count) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      count.itemName,
                      style: instrument(fontSize: 14),
                    ),
                  ),
                  Text(
                    '${count.physicalQty} of ${count.systemQty}',
                    style: instrument(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(width: 10),
                  _VarianceChip(variance: count.variance),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── History ───────────────────────────────────────────────────────────────────

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  final _service = StockCountService();

  List<StockCount> _latest = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final latest = await _service.getLatestCountPerItem();
      if (!mounted) return;
      setState(() {
        _latest = latest;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasError) {
      return _EmptyState(
        icon: Symbols.cloud_off,
        title: 'Could not load history',
        message: 'Something went wrong reading your past counts.',
        action: OutlinedButton(onPressed: _load, child: const Text('Try again')),
      );
    }
    if (_latest.isEmpty) {
      return const _EmptyState(
        icon: Symbols.history,
        title: 'No counts recorded yet',
        message: 'Go to the Count Now tab and submit your first count to '
            'start tracking unexplained loss.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        itemCount: _latest.length,
        itemBuilder: (context, index) => _HistoryRow(count: _latest[index]),
      ),
    );
  }
}

class _HistoryRow extends StatefulWidget {
  final StockCount count;
  const _HistoryRow({required this.count});

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  final _service = StockCountService();
  bool _expanded = false;
  List<StockCount>? _history;
  bool _historyFailed = false;

  Future<void> _toggle() async {
    if (_expanded) {
      setState(() => _expanded = false);
      return;
    }
    setState(() => _expanded = true);
    if (_history != null) return;
    try {
      final history = await _service.getCountHistoryForItem(widget.count.itemId);
      if (!mounted) return;
      setState(() => _history = history);
    } catch (_) {
      if (!mounted) return;
      setState(() => _historyFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.count;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            count.itemName,
                            style: instrument(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(count.countedAt),
                            style: instrument(
                                fontSize: 12, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    _VarianceChip(variance: count.variance),
                    const SizedBox(width: 6),
                    Icon(
                      _expanded ? Symbols.expand_less : Symbols.expand_more,
                      size: 20,
                      color: AppColors.mutedLight,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: _buildHistoryBody(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryBody() {
    if (_historyFailed) {
      return Text(
        'Could not load this item history.',
        style: instrument(fontSize: 13, color: AppColors.red),
      );
    }
    final history = _history;
    if (history == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: history
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDate(entry.countedAt),
                      style:
                          instrument(fontSize: 13, color: AppColors.secondary),
                    ),
                  ),
                  Text(
                    'App ${entry.systemQty} · Counted ${entry.physicalQty}',
                    style: instrument(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(width: 10),
                  _VarianceChip(variance: entry.variance),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

// ── Shared pieces ─────────────────────────────────────────────────────────────

class _VarianceChip extends StatelessWidget {
  final int variance;
  const _VarianceChip({required this.variance});

  @override
  Widget build(BuildContext context) {
    late final Color background;
    late final Color foreground;
    late final String label;

    if (variance < 0) {
      background = AppColors.redLight;
      foreground = AppColors.red;
      label = '− ${variance.abs()}';
    } else if (variance == 0) {
      background = AppColors.paperDark;
      foreground = AppColors.secondary;
      label = '✓ 0';
    } else {
      background = AppColors.greenLight;
      foreground = AppColors.greenDark;
      label = '+ $variance';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: mono(
            fontSize: 12, fontWeight: FontWeight.w700, color: foreground),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: instrument(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.muted,
        letterSpacing: 0.14,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.mutedLight),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: bricolage(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: instrument(fontSize: 13, color: AppColors.muted),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDate(int millis) {
  return DateFormat('d MMM yyyy, h:mm a')
      .format(DateTime.fromMillisecondsSinceEpoch(millis));
}
