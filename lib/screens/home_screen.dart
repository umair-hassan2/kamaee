import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../database_helper.dart';
import '../services/finance_service.dart';
import '../services/khata_service.dart';
import '../services/settings_service.dart';
import '../services/cash_register_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'barcode_scanner_screen.dart';
import 'bulk_restock_scanner_screen.dart';
import 'cash_register_screen.dart';
import 'sales_history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onInventoryTap;

  const HomeScreen({super.key, this.onInventoryTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _financeService = FinanceService();
  final _settingsService = SettingsService();
  final _khataService = KhataService();
  final _cashRegisterService = CashRegisterService();

  double _todayRevenue = 0;
  double _todayProfit = 0;
  int _todaySales = 0;
  int _itemCount = 0;
  double _totalOutstanding = 0;
  bool _registerOpen = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _financeService.getTodaySummary(),
        DatabaseHelper().getAllItems(),
        _khataService.getTotalOutstanding(),
        _cashRegisterService.getActiveSession(),
      ]);
      if (!mounted) return;
      final summary = results[0] as dynamic;
      final items = results[1] as List;
      setState(() {
        _todayRevenue = summary.revenue as double;
        _todayProfit = summary.profit as double;
        _todaySales = (summary.transactionCount as int?) ?? 0;
        _itemCount = items.length;
        _totalOutstanding = results[2] as double;
        _registerOpen = results[3] != null;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToScanner(ScanMode mode) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BarcodeScannerScreen(mode: mode)),
    );
    await _loadData();
  }

  Future<void> _startBulkRestock() async {
    final mode = await showModalBottomSheet<BulkScanMode>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Bulk Restock',
                  style: bricolage(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Choose your scanning method',
                  style: instrument(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 20),
              _ScanModeOption(
                icon: Symbols.barcode_scanner,
                label: 'Scan Barcodes',
                subtitle: 'EAN-13, Code128, UPC and more',
                onTap: () => Navigator.pop(ctx, BulkScanMode.barcode),
              ),
              const SizedBox(height: 10),
              _ScanModeOption(
                icon: Symbols.qr_code_scanner,
                label: 'Scan QR Codes',
                subtitle: 'Standard QR codes',
                onTap: () => Navigator.pop(ctx, BulkScanMode.qr),
              ),
            ],
          ),
        ),
      ),
    );

    if (mode != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BulkRestockScannerScreen(mode: mode),
        ),
      );
      await _loadData();
    }
  }

  Future<void> _navigateToCashRegister() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CashRegisterScreen()),
    );
    await _loadData();
  }

  Future<void> _navigateToSalesHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SalesHistoryScreen()),
    );
  }

  Future<void> _navigateToSettings() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (updated == true) await _loadData();
  }

  String _dateLabel() {
    final now = DateTime.now();
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final shopName = _settingsService.settings.shopName;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.green,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, topPadding + 14, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.greenLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Symbols.storefront,
                              color: AppColors.green, size: 24, fill: 1),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                shopName.isNotEmpty ? shopName : 'Kamaae',
                                style: bricolage(fontSize: 19, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                _dateLabel(),
                                style: instrument(fontSize: 12.5, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _navigateToSettings,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(Symbols.settings,
                                size: 21, color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // ── Hero stats card ──────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TODAY'S REVENUE",
                            style: instrument(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkMuted,
                              letterSpacing: 0.16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _isLoading
                              ? Container(
                                  height: 44,
                                  width: 160,
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                )
                              : Text(
                                  formatPkr(_todayRevenue),
                                  style: mono(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onDark,
                                    letterSpacing: -0.02,
                                  ),
                                ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _DarkStatTile(
                                  label: 'Profit',
                                  value: formatPkr(_todayProfit),
                                  valueColor: AppColors.greenBright,
                                  isLoading: _isLoading,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DarkStatTile(
                                  label: 'Sales',
                                  value: '$_todaySales',
                                  suffix: 'txns',
                                  valueColor: AppColors.onDark,
                                  isLoading: _isLoading,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Outstanding khata banner ─────────────────────────────
                    if (_totalOutstanding > 0) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.amberLight,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: const Color(0xFFEAD6AE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Symbols.account_balance_wallet,
                                size: 18,
                                color: AppColors.amber,
                                fill: 1),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Outstanding khata',
                                style: instrument(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.amberDark,
                                ),
                              ),
                            ),
                            Text(
                              formatPkr(_totalOutstanding),
                              style: mono(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.amberDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),

                    // ── Quick actions label ──────────────────────────────────
                    Text(
                      'QUICK ACTIONS',
                      style: instrument(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                        letterSpacing: 0.14,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _ActionGrid(
                    items: [
                      _ActionItem(
                        icon: Symbols.barcode_scanner,
                        label: 'Scan Barcode',
                        subtitle: 'Sell or restock',
                        bgColor: AppColors.greenLight,
                        iconColor: AppColors.green,
                        onTap: () => _navigateToScanner(ScanMode.barcode),
                      ),
                      _ActionItem(
                        icon: Symbols.qr_code_scanner,
                        label: 'Scan QR',
                        subtitle: 'Sell or restock',
                        bgColor: AppColors.tealLight,
                        iconColor: AppColors.teal,
                        onTap: () => _navigateToScanner(ScanMode.qr),
                      ),
                      _ActionItem(
                        icon: Symbols.point_of_sale,
                        label: 'Cash Register',
                        subtitle: _registerOpen ? 'Session open' : 'Tap to open',
                        bgColor: AppColors.greenLight,
                        iconColor: AppColors.green,
                        badge: _registerOpen ? 'OPEN' : null,
                        onTap: _navigateToCashRegister,
                      ),
                      _ActionItem(
                        icon: Symbols.receipt_long,
                        label: 'Sales History',
                        subtitle: 'Past bills & sales',
                        bgColor: AppColors.amberLight,
                        iconColor: AppColors.amber,
                        onTap: _navigateToSalesHistory,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _BulkRestockCard(onTap: _startBulkRestock),
                  const SizedBox(height: 20),
                  _InventoryStrip(
                    itemCount: _itemCount,
                    onTap: widget.onInventoryTap,
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dark stat tile (inside hero card) ─────────────────────────────────────────

class _DarkStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  final Color valueColor;
  final bool isLoading;

  const _DarkStatTile({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.isLoading,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: instrument(fontSize: 11, color: AppColors.inkMuted)),
          const SizedBox(height: 4),
          if (isLoading)
            Container(
              height: 18,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(4),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value,
                    style: mono(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: valueColor)),
                if (suffix != null) ...[
                  const SizedBox(width: 4),
                  Text(suffix!,
                      style: instrument(
                          fontSize: 12, color: AppColors.inkMuted)),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

// ── Action grid ───────────────────────────────────────────────────────────────

class _ActionItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color bgColor;
  final Color iconColor;
  final String? badge;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
    this.badge,
  });
}

class _ActionGrid extends StatelessWidget {
  final List<_ActionItem> items;
  const _ActionGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _ActionCard(item: items[0])),
            const SizedBox(width: 12),
            Expanded(child: _ActionCard(item: items[1])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _ActionCard(item: items[2])),
            const SizedBox(width: 12),
            Expanded(child: _ActionCard(item: items[3])),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final _ActionItem item;
  const _ActionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 118,
          child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item.bgColor,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(item.icon, color: item.iconColor, size: 23),
                  ),
                  if (item.badge != null) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.greenLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.badge!,
                        style: instrument(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.green,
                          letterSpacing: 0.06,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              Text(
                item.label,
                style: instrument(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                style: instrument(fontSize: 11.5, color: AppColors.muted),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

// ── Bulk restock card ─────────────────────────────────────────────────────────

class _BulkRestockCard extends StatelessWidget {
  final VoidCallback onTap;
  const _BulkRestockCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.blueLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Symbols.inventory_2,
                    size: 20, color: AppColors.blue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bulk Restock',
                        style: instrument(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink)),
                    const SizedBox(height: 1),
                    Text('Scan to build a restock list, then confirm',
                        style:
                            instrument(fontSize: 11.5, color: AppColors.muted)),
                  ],
                ),
              ),
              const Icon(Symbols.chevron_right,
                  size: 18, color: AppColors.mutedLight),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Scan mode option (inside bottom sheet) ────────────────────────────────────

class _ScanModeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ScanModeOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.green, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: instrument(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: instrument(
                            fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              const Icon(Symbols.arrow_forward,
                  size: 18, color: AppColors.mutedLight),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Inventory summary strip ───────────────────────────────────────────────────

class _InventoryStrip extends StatelessWidget {
  final int itemCount;
  final VoidCallback? onTap;
  const _InventoryStrip({required this.itemCount, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.blueLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Symbols.inventory_2,
                    size: 18, color: AppColors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$itemCount products in inventory',
                  style: instrument(fontSize: 13, color: AppColors.muted),
                ),
              ),
              const Icon(Symbols.chevron_right,
                  size: 18, color: AppColors.mutedLight),
            ],
          ),
        ),
      ),
    );
  }
}
