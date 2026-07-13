import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../models/customer.dart';
import '../models/khata_entry.dart';
import '../models/sale.dart';
import '../services/khata_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'sale_detail_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen>
    with SingleTickerProviderStateMixin {
  final _khataService = KhataService();
  final _db = DatabaseHelper();
  late Customer _customer;
  List<KhataEntry> _entries = [];
  List<Sale> _sales = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _khataService.getCustomerById(_customer.id!),
      _khataService.getEntriesForCustomer(_customer.id!),
      _db.getSalesByCustomer(_customer.id!),
    ]);
    if (!mounted) return;
    setState(() {
      _customer = (results[0] as Customer?) ?? _customer;
      _entries = results[1] as List<KhataEntry>;
      _sales = results[2] as List<Sale>;
      _isLoading = false;
    });
  }

  void _showEntrySheet({required KhataEntryType entryType}) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final isCredit = entryType == KhataEntryType.credit;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isCredit ? AppColors.danger : AppColors.sell)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isCredit
                          ? Icons.arrow_upward_outlined
                          : Icons.arrow_downward_outlined,
                      color: isCredit ? AppColors.danger : AppColors.sell,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isCredit ? 'Give Credit' : 'Record Payment',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (Rs) *',
                  hintText: '0',
                  border: const OutlineInputBorder(),
                  prefixText: 'Rs ',
                  prefixIcon: Icon(Icons.currency_rupee,
                      color: isCredit ? AppColors.danger : AppColors.sell),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Amount is required';
                  final amount = double.tryParse(v.trim());
                  if (amount == null || amount <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Doodh aur chai patti',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final entry = KhataEntry(
                    customerId: _customer.id!,
                    type: entryType,
                    amount: double.parse(amountController.text.trim()),
                    note: noteController.text.trim().isNotEmpty
                        ? noteController.text.trim()
                        : null,
                    timestamp: DateTime.now().millisecondsSinceEpoch,
                  );
                  await _khataService.addEntry(entry);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  await _loadData();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: isCredit ? AppColors.danger : AppColors.sell,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(isCredit ? 'Add Credit' : 'Record Payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteEntry(KhataEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Delete this khata entry? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _khataService.deleteEntry(entry.id!);
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = _customer.balance;
    final hasBalance = balance > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_customer.name),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            const Tab(text: 'Khata'),
            Tab(text: 'Sales (${_sales.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _KhataTab(
                    customer: _customer,
                    entries: _entries,
                    hasBalance: hasBalance,
                    balance: balance,
                    onCredit: () => _showEntrySheet(entryType: KhataEntryType.credit),
                    onPayment: () => _showEntrySheet(entryType: KhataEntryType.payment),
                    onDelete: _deleteEntry,
                  ),
                  _SalesTab(sales: _sales, customerName: _customer.name),
                ],
              ),
            ),
    );
  }
}

// ─── Khata Tab ────────────────────────────────────────────────────────────────

class _KhataTab extends StatelessWidget {
  final Customer customer;
  final List<KhataEntry> entries;
  final bool hasBalance;
  final double balance;
  final VoidCallback onCredit;
  final VoidCallback onPayment;
  final Future<void> Function(KhataEntry) onDelete;

  const _KhataTab({
    required this.customer,
    required this.entries,
    required this.hasBalance,
    required this.balance,
    required this.onCredit,
    required this.onPayment,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Balance Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: hasBalance
                  ? [
                      AppColors.warning.withValues(alpha: 0.15),
                      AppColors.warning.withValues(alpha: 0.05),
                    ]
                  : [
                      AppColors.sell.withValues(alpha: 0.15),
                      AppColors.sell.withValues(alpha: 0.05),
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasBalance
                  ? AppColors.warning.withValues(alpha: 0.3)
                  : AppColors.sell.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasBalance
                        ? Icons.warning_amber_outlined
                        : Icons.check_circle_outline,
                    color: hasBalance ? AppColors.warning : AppColors.sell,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasBalance ? 'Outstanding Balance' : 'All Clear',
                    style: TextStyle(
                      color: hasBalance ? AppColors.warning : AppColors.sell,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                formatPkr(balance),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: hasBalance ? AppColors.warning : AppColors.sell,
                  letterSpacing: -1,
                ),
              ),
              if (customer.phone.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 14, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(customer.phone,
                        style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onCredit,
                icon: const Icon(Icons.arrow_upward_outlined),
                label: const Text('Give Credit'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: onPayment,
                icon: const Icon(Icons.arrow_downward_outlined),
                label: const Text('Record Payment'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sell,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Text('History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${entries.length}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Text(
              'No entries yet. Use the buttons above to add credit or record a payment.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          ...entries.map((entry) => _EntryTile(
                entry: entry,
                onDelete: () => onDelete(entry),
              )),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─── Sales Tab ────────────────────────────────────────────────────────────────

class _SalesTab extends StatelessWidget {
  final List<Sale> sales;
  final String customerName;

  const _SalesTab({required this.sales, required this.customerName});

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 56, color: AppColors.muted),
            SizedBox(height: 12),
            Text('No sales yet',
                style: TextStyle(fontSize: 16, color: AppColors.muted)),
            SizedBox(height: 6),
            Text('Sales made to this customer will appear here',
                style: TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sales.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _SaleTile(sale: sales[i], customerName: customerName),
    );
  }
}

class _SaleTile extends StatelessWidget {
  final Sale sale;
  final String? customerName;

  const _SaleTile({required this.sale, this.customerName});

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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SaleDetailScreen(sale: sale, customerName: customerName),
          ),
        ),
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
                Text(dateStr,
                    style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                      Text('${formatPkr(sale.khataAmount)} on credit',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.warning)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            formatPkr(sale.totalAmount),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

// ─── Entry Tile ───────────────────────────────────────────────────────────────

class _EntryTile extends StatelessWidget {
  final KhataEntry entry;
  final VoidCallback onDelete;

  const _EntryTile({required this.entry, required this.onDelete});

  Future<void> _openSale(BuildContext context) async {
    final db = DatabaseHelper();
    final rows = await db.database.then((d) => d.query(
          'sales',
          where: 'id = ?',
          whereArgs: [entry.saleId],
        ));
    if (rows.isEmpty || !context.mounted) return;
    final sale = Sale.fromMap(rows.first);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SaleDetailScreen(sale: sale)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = entry.type == KhataEntryType.credit;
    final color = isCredit ? AppColors.danger : AppColors.sell;
    final dt = DateTime.fromMillisecondsSinceEpoch(entry.timestamp);
    final dateStr = DateFormat('d MMM yyyy, h:mm a').format(dt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCredit ? Icons.arrow_upward_outlined : Icons.arrow_downward_outlined,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isCredit ? 'Credit' : 'Payment',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatPkr(entry.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: color,
                      ),
                    ),
                  ],
                ),
                if (entry.note != null && entry.note!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    entry.note!,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(dateStr,
                        style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    if (entry.saleId != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _openSale(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_outlined,
                                  size: 11, color: AppColors.primary),
                              SizedBox(width: 3),
                              Text('View Sale',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.grey.shade400),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
