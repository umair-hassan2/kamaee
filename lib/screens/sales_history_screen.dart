import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../database_helper.dart';
import '../models/sale.dart';
import '../services/khata_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'sale_detail_screen.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final _db = DatabaseHelper();
  final _khataService = KhataService();
  List<Sale> _sales = [];
  Map<int, String> _customerNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final sales = await _db.getAllCompletedSales();
    final customerIds =
        sales.map((s) => s.customerId).whereType<int>().toSet();
    final names = <int, String>{};
    for (final id in customerIds) {
      final c = await _khataService.getCustomerById(id);
      if (c != null) names[id] = c.name;
    }
    if (mounted) {
      setState(() {
        _sales = sales;
        _customerNames = names;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  Text('Sales History',
                      style: bricolage(
                          fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppColors.green,
                      child: _sales.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: AppColors.amberLight,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(Symbols.receipt_long,
                                        size: 36, color: AppColors.amber),
                                  ),
                                  const SizedBox(height: 16),
                                  Text('No sales yet',
                                      style: instrument(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.ink)),
                                  const SizedBox(height: 6),
                                  Text('Completed sales will appear here',
                                      style: instrument(
                                          fontSize: 13,
                                          color: AppColors.muted)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                              itemCount: _sales.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final sale = _sales[i];
                                final customerName = sale.customerId != null
                                    ? _customerNames[sale.customerId!]
                                    : null;
                                return _SaleHistoryTile(
                                  sale: sale,
                                  customerName: customerName,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SaleDetailScreen(
                                        sale: sale,
                                        customerName: customerName,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sale history tile ─────────────────────────────────────────────────────────

class _SaleHistoryTile extends StatelessWidget {
  final Sale sale;
  final String? customerName;
  final VoidCallback onTap;

  const _SaleHistoryTile({
    required this.sale,
    required this.onTap,
    this.customerName,
  });

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(sale.timestamp);
    final dateStr = DateFormat('d MMM yyyy, h:mm a').format(dt);

    final ({Color iconBg, Color iconColor, Color textBg, Color textColor,
        IconData icon, String label}) method = switch (sale.paymentMethod) {
      PaymentMethod.cash => (
          iconBg: AppColors.greenLight,
          iconColor: AppColors.green,
          textBg: AppColors.greenLight,
          textColor: AppColors.greenDark,
          icon: Symbols.payments,
          label: 'Cash',
        ),
      PaymentMethod.khata => (
          iconBg: AppColors.amberLight,
          iconColor: AppColors.amber,
          textBg: AppColors.amberLight,
          textColor: AppColors.amberDark,
          icon: Symbols.account_balance_wallet,
          label: 'Full Khata',
        ),
      PaymentMethod.partial => (
          iconBg: AppColors.tealLight,
          iconColor: AppColors.teal,
          textBg: AppColors.tealLight,
          textColor: AppColors.tealDark,
          icon: Symbols.call_split,
          label: 'Partial',
        ),
    };

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
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
                  color: method.iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(method.icon, color: method.iconColor, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (customerName != null)
                      Text(customerName!,
                          style: instrument(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(dateStr,
                        style: mono(fontSize: 12, color: AppColors.muted)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: method.textBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(method.label,
                              style: instrument(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: method.textColor)),
                        ),
                        if (sale.khataAmount > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${formatPkr(sale.khataAmount)} on khata',
                            style:
                                mono(fontSize: 11, color: AppColors.amber),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatPkr(sale.totalAmount),
                    style: mono(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink),
                  ),
                  Text(
                    '#${sale.id}',
                    style: mono(fontSize: 11, color: AppColors.mutedLight),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
