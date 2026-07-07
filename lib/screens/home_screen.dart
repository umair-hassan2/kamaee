import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database_helper.dart';
import '../theme/app_theme.dart';
import 'barcode_scanner_screen.dart';
import 'inventory_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _balance = 0.0;
  int _itemCount = 0;
  int _totalUnits = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final items = await DatabaseHelper().getAllItems();
    if (!mounted) return;
    setState(() {
      _balance = prefs.getDouble('balance') ?? 0.0;
      _itemCount = items.length;
      _totalUnits = items.fold(0, (sum, item) => sum + item.quantity);
    });
  }

  Future<void> _resetBalance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('balance', 0.0);
    setState(() => _balance = 0.0);
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

  String _formatBalance(double amount) => '\$${amount.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'reset') _showResetConfirmation();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'reset',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, color: AppColors.danger),
                        SizedBox(width: 8),
                        Text('Reset Balance'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Kamaae'),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                ),
                child: const Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Icon(
                      Icons.storefront,
                      size: 80,
                      color: Colors.white24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF134E4A), AppColors.primaryDark],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Today\'s Revenue',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatBalance(_balance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _BalanceStat(
                              label: 'Products',
                              value: '$_itemCount',
                            ),
                            const SizedBox(width: 24),
                            _BalanceStat(
                              label: 'Units in stock',
                              value: '$_totalUnits',
                            ),
                          ],
                        ),
                      ],
                    ),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation() {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Balance'),
        content: const Text(
          'Are you sure you want to reset today\'s revenue to \$0.00?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
              _resetBalance();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label;
  final String value;

  const _BalanceStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
                  color: color.withOpacity(0.12),
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
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
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
