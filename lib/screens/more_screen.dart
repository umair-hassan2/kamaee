import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'cash_register_screen.dart';
import 'finance_screen.dart';
import 'sales_history_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final _settings = SettingsService();

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final shopName = _settings.settings.shopName;
    final ownerName = _settings.settings.ownerName;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(shopName, ownerName, topPadding),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionLabel('Analytics'),
                const SizedBox(height: 10),
                _MenuCard(items: [
                  _MenuItem(
                    icon: Symbols.trending_up,
                    iconColor: AppColors.sell,
                    label: 'Cash Flow',
                    subtitle: 'Charts, history & cost analysis',
                    onTap: () => _push(const FinanceScreen()),
                  ),
                  _MenuItem(
                    icon: Symbols.receipt_long,
                    iconColor: AppColors.primary,
                    label: 'Sales History',
                    subtitle: 'Browse all past sales & bills',
                    onTap: () => _push(const SalesHistoryScreen()),
                  ),
                ]),
                const SizedBox(height: 20),
                _SectionLabel('Operations'),
                const SizedBox(height: 10),
                _MenuCard(items: [
                  _MenuItem(
                    icon: Symbols.point_of_sale,
                    iconColor: AppColors.primary,
                    label: 'Cash Register',
                    subtitle: 'Open & close daily register',
                    onTap: () => _push(const CashRegisterScreen()),
                  ),
                ]),
                const SizedBox(height: 20),
                _SectionLabel('Preferences'),
                const SizedBox(height: 10),
                _MenuCard(items: [
                  _MenuItem(
                    icon: Symbols.settings,
                    iconColor: AppColors.muted,
                    label: 'Settings',
                    subtitle: 'Shop profile, currency, alerts',
                    onTap: () => _push(const SettingsScreen()),
                  ),
                ]),
                const SizedBox(height: 28),
                Center(
                  child: Text(
                    'Kamaae · v1.0.0',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.mutedLight),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String shopName, String ownerName, double topPadding) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Symbols.storefront,
                color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shopName.isNotEmpty ? shopName : 'Kamaae',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neutralDark,
                  ),
                ),
                if (ownerName.isNotEmpty)
                  Text(ownerName,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.muted)),
              ],
            ),
          ),
        ],
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
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.muted,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
}

class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final isLast = i == items.length - 1;
          return Column(
            children: [
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? const Radius.circular(16) : Radius.zero,
                  bottom: isLast ? const Radius.circular(16) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: item.iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon,
                            color: item.iconColor, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.label,
                                style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.neutralDark)),
                            Text(item.subtitle,
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      const Icon(Symbols.chevron_right,
                          size: 18, color: AppColors.mutedLight),
                    ],
                  ),
                ),
              ),
              if (!isLast) const Divider(height: 1, indent: 70),
            ],
          );
        }),
      ),
    );
  }
}
