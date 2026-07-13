import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
      appBar: AppBar(
        title: const Text('Sales History'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _sales.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 56, color: AppColors.muted),
                          SizedBox(height: 12),
                          Text('No sales yet',
                              style: TextStyle(
                                  fontSize: 16, color: AppColors.muted)),
                          SizedBox(height: 6),
                          Text('Completed sales will appear here',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.muted)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _sales.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
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
    );
  }
}

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

    Color methodColor;
    IconData methodIcon;
    String methodLabel;
    switch (sale.paymentMethod) {
      case PaymentMethod.cash:
        methodColor = AppColors.sell;
        methodIcon = Icons.payments_outlined;
        methodLabel = 'Cash';
      case PaymentMethod.khata:
        methodColor = AppColors.warning;
        methodIcon = Icons.account_balance_wallet_outlined;
        methodLabel = 'Full Khata';
      case PaymentMethod.partial:
        methodColor = AppColors.accent;
        methodIcon = Icons.call_split_outlined;
        methodLabel = 'Partial';
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: methodColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(methodIcon, color: methodColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (customerName != null)
                      Text(customerName!,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(dateStr,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: methodColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(methodLabel,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: methodColor)),
                        ),
                        if (sale.khataAmount > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${formatPkr(sale.khataAmount)} on khata',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.warning),
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
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.primaryDark),
                  ),
                  Text(
                    '#${sale.id}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.muted),
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
