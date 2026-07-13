import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../database_helper.dart';
import '../services/finance_service.dart';
import '../services/khata_service.dart';
import '../services/settings_service.dart';
import '../services/cash_register_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'barcode_scanner_screen.dart';
import 'cash_register_screen.dart';
import 'sales_history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final shopName = _settingsService.settings.shopName;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                topPadding: topPadding,
                shopName: shopName.isNotEmpty ? shopName : 'Kamaae',
                onSettingsTap: _navigateToSettings,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _StatsRow(
                    revenue: _todayRevenue,
                    profit: _todayProfit,
                    isLoading: _isLoading,
                  ),
                  if (_totalOutstanding > 0) ...[
                    const SizedBox(height: 12),
                    _OutstandingStrip(amount: _totalOutstanding),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    'QUICK ACTIONS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ActionGrid(
                    items: [
                      _ActionItem(
                        icon: Symbols.barcode_scanner,
                        label: 'Scan Barcode',
                        subtitle: 'Sell or restock',
                        color: AppColors.primary,
                        onTap: () => _navigateToScanner(ScanMode.barcode),
                      ),
                      _ActionItem(
                        icon: Symbols.qr_code_scanner,
                        label: 'Scan QR',
                        subtitle: 'Sell or restock',
                        color: AppColors.accent,
                        onTap: () => _navigateToScanner(ScanMode.qr),
                      ),
                      _ActionItem(
                        icon: Symbols.point_of_sale,
                        label: 'Cash Register',
                        subtitle: _registerOpen ? 'Session open' : 'Tap to open',
                        color: AppColors.sell,
                        badge: _registerOpen ? 'OPEN' : null,
                        onTap: _navigateToCashRegister,
                      ),
                      _ActionItem(
                        icon: Symbols.receipt_long,
                        label: 'Sales History',
                        subtitle: 'Past bills & sales',
                        color: AppColors.warning,
                        onTap: _navigateToSalesHistory,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _InventorySummary(itemCount: _itemCount),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final double topPadding;
  final String shopName;
  final VoidCallback onSettingsTap;

  const _Header({
    required this.topPadding,
    required this.shopName,
    required this.onSettingsTap,
  });

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
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(20, topPadding + 14, 8, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Symbols.storefront,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shopName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neutralDark,
                    height: 1.15,
                  ),
                ),
                Text(
                  _dateLabel(),
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onSettingsTap,
            icon: const Icon(Symbols.settings,
                size: 22, color: AppColors.muted),
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final double revenue;
  final double profit;
  final bool isLoading;

  const _StatsRow({
    required this.revenue,
    required this.profit,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Revenue',
            value: formatPkr(revenue),
            icon: Symbols.trending_up,
            iconColor: AppColors.sell,
            bgColor: AppColors.sellLight,
            isLoading: isLoading,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Profit',
            value: formatPkr(profit),
            icon: Symbols.monetization_on,
            iconColor: AppColors.primary,
            bgColor: AppColors.primaryLight,
            isLoading: isLoading,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final bool isLoading;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const Spacer(),
              Text(
                'Today',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.mutedLight),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            Container(
              height: 22,
              width: 72,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            )
          else
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.neutralDark,
                letterSpacing: -0.5,
              ),
            ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

// ── Outstanding Strip ─────────────────────────────────────────────────────────

class _OutstandingStrip extends StatelessWidget {
  final double amount;
  const _OutstandingStrip({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Symbols.warning, size: 16,
              color: AppColors.warning, fill: 1),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Outstanding khata',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.warning),
            ),
          ),
          Text(
            formatPkr(amount),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Grid ───────────────────────────────────────────────────────────────

class _ActionItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge,
  });
}

class _ActionGrid extends StatelessWidget {
  final List<_ActionItem> items;
  const _ActionGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.05,
      children: items.map((item) => _ActionCard(item: item)).toList(),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final _ActionItem item;
  const _ActionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: item.color, size: 22),
                  ),
                  if (item.badge != null) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.sell.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.badge!,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sell,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              Text(
                item.label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutralDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Inventory Summary Strip ───────────────────────────────────────────────────

class _InventorySummary extends StatelessWidget {
  final int itemCount;
  const _InventorySummary({required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.restock.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Symbols.inventory_2,
                size: 16, color: AppColors.restock),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$itemCount products in inventory',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
            ),
          ),
          const Icon(Symbols.chevron_right,
              size: 18, color: AppColors.mutedLight),
        ],
      ),
    );
  }
}
