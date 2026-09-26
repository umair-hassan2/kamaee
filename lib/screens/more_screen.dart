import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../services/cash_register_service.dart';
import '../services/daily_report_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/whatsapp_share.dart';
import 'cash_register_screen.dart';
import 'finance_screen.dart';
import 'sales_history_screen.dart';
import 'settings_screen.dart';
import 'stock_audit_screen.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final _settings = SettingsService();
  final _cashRegisterService = CashRegisterService();
  final _reportService = DailyReportService();
  bool _registerOpen = false;

  @override
  void initState() {
    super.initState();
    _checkRegister();
  }

  Future<void> _checkRegister() async {
    final session = await _cashRegisterService.getActiveSession();
    if (mounted) setState(() => _registerOpen = session != null);
  }

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) {
      setState(() {});
      await _checkRegister();
    }
  }

  Future<void> _sendDailyReport() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Generating report…'),
        duration: Duration(seconds: 10),
      ),
    );
    try {
      final text = await _reportService.generateTodayReport();
      messenger.hideCurrentSnackBar();
      await WhatsAppShare.share(text);
    } catch (_) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to generate report')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final shopName = _settings.settings.shopName;
    final ownerName = _settings.settings.ownerName;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, topPadding + 14, 20, 26),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.greenLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Symbols.storefront,
                        color: AppColors.green, size: 28, fill: 1),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shopName.isNotEmpty ? shopName : 'Kamaae',
                          style: bricolage(
                              fontSize: 21, fontWeight: FontWeight.w700),
                        ),
                        if (ownerName.isNotEmpty)
                          Text(ownerName,
                              style: instrument(
                                  fontSize: 13, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _SectionLabel('Analytics'),
                const SizedBox(height: 10),
                _MenuGroup(items: [
                  _MenuEntry(
                    icon: Symbols.trending_up,
                    iconBg: AppColors.greenLight,
                    iconColor: AppColors.green,
                    label: 'Cash Flow',
                    subtitle: 'Charts, history & cost analysis',
                    onTap: () => _push(const FinanceScreen()),
                  ),
                  _MenuEntry(
                    icon: Symbols.receipt_long,
                    iconBg: AppColors.amberLight,
                    iconColor: AppColors.amber,
                    label: 'Sales History',
                    subtitle: 'Browse all past sales & bills',
                    onTap: () => _push(const SalesHistoryScreen()),
                  ),
                  _MenuEntry(
                    icon: Symbols.send,
                    iconBg: AppColors.greenLight,
                    iconColor: AppColors.green,
                    label: 'Daily WhatsApp Report',
                    subtitle: "Share today's summary on WhatsApp",
                    onTap: _sendDailyReport,
                  ),
                ]),
                const SizedBox(height: 20),
                const _SectionLabel('Operations'),
                const SizedBox(height: 10),
                _MenuGroup(items: [
                  _MenuEntry(
                    icon: Symbols.point_of_sale,
                    iconBg: AppColors.greenLight,
                    iconColor: AppColors.green,
                    label: 'Cash Register',
                    subtitle: 'Open & close daily register',
                    badge: _registerOpen ? 'OPEN' : null,
                    onTap: () => _push(const CashRegisterScreen()),
                  ),
                  _MenuEntry(
                    icon: Symbols.fact_check,
                    iconBg: AppColors.tealLight,
                    iconColor: AppColors.teal,
                    label: 'Stock Audit',
                    subtitle: 'Count shelf stock & track shortages',
                    onTap: () => _push(const StockAuditScreen()),
                  ),
                ]),
                const SizedBox(height: 20),
                const _SectionLabel('Preferences'),
                const SizedBox(height: 10),
                _MenuGroup(items: [
                  _MenuEntry(
                    icon: Symbols.settings,
                    iconBg: AppColors.paperDark,
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
                    style: instrument(fontSize: 12, color: AppColors.mutedLight),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

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

// ── Menu entry data ───────────────────────────────────────────────────────────

class _MenuEntry {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _MenuEntry({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });
}

// ── Menu group ────────────────────────────────────────────────────────────────

class _MenuGroup extends StatelessWidget {
  final List<_MenuEntry> items;
  const _MenuGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final entry = items[i];
          final isLast = i == items.length - 1;
          return Column(
            children: [
              InkWell(
                onTap: entry.onTap,
                borderRadius: BorderRadius.vertical(
                  top: i == 0 ? const Radius.circular(16) : Radius.zero,
                  bottom: isLast ? const Radius.circular(16) : Radius.zero,
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: entry.iconBg,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(entry.icon,
                            color: entry.iconColor, size: 21),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.label,
                                style: instrument(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink)),
                            Text(entry.subtitle,
                                style: instrument(
                                    fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      if (entry.badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.greenLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            entry.badge!,
                            style: instrument(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.greenDark,
                              letterSpacing: 0.06,
                            ),
                          ),
                        )
                      else
                        const Icon(Symbols.chevron_right,
                            size: 20, color: AppColors.mutedLight),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                const Divider(height: 1, indent: 70, color: AppColors.border),
            ],
          );
        }),
      ),
    );
  }
}
