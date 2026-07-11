import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../services/finance_service.dart';
import '../services/khata_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'barcode_scanner_screen.dart';
import 'finance_screen.dart';
import 'inventory_screen.dart';
import 'khata_screen.dart';
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
  double _todayRevenue = 0;
  double _todayProfit = 0;
  int _itemCount = 0;
  int _totalUnits = 0;
  double _totalOutstanding = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _financeService.getTodaySummary(),
      DatabaseHelper().getAllItems(),
      _khataService.getTotalOutstanding(),
    ]);
    if (!mounted) return;
    final summary = results[0] as dynamic;
    final items = results[1] as List;
    final outstanding = results[2] as double;
    setState(() {
      _todayRevenue = summary.revenue as double;
      _todayProfit = summary.profit as double;
      _itemCount = items.length;
      _totalUnits = items.fold(0, (sum, item) => sum + (item.quantity as int));
      _totalOutstanding = outstanding;
    });
  }

  Future<void> _navigateToScanner(ScanMode mode) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerScreen(mode: mode),
      ),
    );
    await _loadData();
  }

  Future<void> _navigateToInventory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InventoryScreen()),
    );
    await _loadData();
  }

  Future<void> _navigateToFinance() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FinanceScreen()),
    );
    await _loadData();
  }

  Future<void> _navigateToSettings() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    if (updated == true) {
      await _loadData();
      if (mounted) setState(() {});
    }
  }

  Future<void> _navigateToKhata() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const KhataScreen()),
    );
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _HomeHeader(
                shopName: _settingsService.settings.shopName,
                ownerName: _settingsService.settings.ownerName,
                onSettingsTap: _navigateToSettings,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TodaySummaryCard(
                      revenue: _todayRevenue,
                      profit: _todayProfit,
                      itemCount: _itemCount,
                      totalUnits: _totalUnits,
                      totalOutstanding: _totalOutstanding,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ActionCard(
                      title: 'Scan Barcode',
                      subtitle: 'Sell or restock with product barcodes',
                      icon: Icons.barcode_reader,
                      color: AppColors.primary,
                      onTap: () => _navigateToScanner(ScanMode.barcode),
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      title: 'Scan QR Code',
                      subtitle: 'Sell or restock with QR codes',
                      icon: Icons.qr_code_2,
                      color: AppColors.accent,
                      onTap: () => _navigateToScanner(ScanMode.qr),
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      title: 'View Inventory',
                      subtitle: 'Browse, search, and manage stock',
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.restock,
                      onTap: _navigateToInventory,
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      title: 'Cash Flow',
                      subtitle: 'Charts, history, and cost analysis',
                      icon: Icons.insights_outlined,
                      color: AppColors.sell,
                      onTap: _navigateToFinance,
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      title: 'Khata / Udhaar',
                      subtitle: 'Track customer credit and payments',
                      icon: Icons.account_balance_wallet_outlined,
                      color: AppColors.warning,
                      onTap: _navigateToKhata,
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      title: 'Settings',
                      subtitle: 'Shop profile, currency, stock alerts',
                      icon: Icons.settings_outlined,
                      color: AppColors.muted,
                      onTap: _navigateToSettings,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final String shopName;
  final String ownerName;
  final VoidCallback onSettingsTap;

  const _HomeHeader({
    required this.shopName,
    required this.ownerName,
    required this.onSettingsTap,
  });

  String get _title => shopName.isNotEmpty ? shopName : 'Kamaae';

  String get _subtitle {
    if (ownerName.isNotEmpty) return ownerName;
    return 'Inventory & sales';
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/kamaae_splash_logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onSettingsTap,
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  final double revenue;
  final double profit;
  final int itemCount;
  final int totalUnits;
  final double totalOutstanding;

  const _TodaySummaryCard({
    required this.revenue,
    required this.profit,
    required this.itemCount,
    required this.totalUnits,
    required this.totalOutstanding,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TodayMetric(
                    label: 'Revenue',
                    value: formatPkr(revenue),
                    color: AppColors.sell,
                  ),
                ),
                Container(
                  width: 1,
                  height: 48,
                  color: Colors.grey.shade200,
                ),
                Expanded(
                  child: _TodayMetric(
                    label: 'Profit',
                    value: formatPkr(profit),
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: totalOutstanding > 0
                    ? AppColors.warning.withValues(alpha: 0.08)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: totalOutstanding > 0
                    ? Border.all(
                        color: AppColors.warning.withValues(alpha: 0.25),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 16,
                    color: totalOutstanding > 0
                        ? AppColors.warning
                        : AppColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Udhaar Outstanding',
                      style: TextStyle(
                        fontSize: 12,
                        color: totalOutstanding > 0
                            ? AppColors.warning
                            : AppColors.muted,
                      ),
                    ),
                  ),
                  Text(
                    formatPkr(totalOutstanding),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: totalOutstanding > 0
                          ? AppColors.warning
                          : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _StockPill(
                    icon: Icons.category_outlined,
                    label: '$itemCount products',
                  ),
                  const SizedBox(width: 12),
                  _StockPill(
                    icon: Icons.inventory_outlined,
                    label: '$totalUnits units in stock',
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

class _TodayMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TodayMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StockPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
