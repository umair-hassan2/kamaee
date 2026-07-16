import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
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
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCredit ? AppColors.redLight : AppColors.greenLight,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      isCredit ? Symbols.arrow_upward : Symbols.arrow_downward,
                      color: isCredit ? AppColors.red : AppColors.green,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isCredit ? 'Give Credit' : 'Record Payment',
                    style: bricolage(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: amountController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: mono(fontSize: 15, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Amount (Rs) *',
                  hintText: '0',
                  prefixText: 'Rs ',
                  prefixStyle: mono(fontSize: 13, color: AppColors.muted),
                  prefixIcon: Icon(
                    Symbols.currency_rupee,
                    color: isCredit ? AppColors.red : AppColors.green,
                  ),
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
                style: instrument(fontSize: 15),
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Doodh aur chai patti',
                  prefixIcon: Icon(Symbols.notes),
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
                  backgroundColor: isCredit ? AppColors.red : AppColors.green,
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
        title: Text('Delete Entry',
            style: bricolage(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text('Delete this khata entry? This cannot be undone.',
            style: instrument(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
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
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Symbols.arrow_back,
                        size: 24, color: AppColors.ink),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_customer.name,
                        style: bricolage(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),

            // ── Tabs ──────────────────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: TabBar(
                controller: _tabController,
                tabs: [
                  const Tab(text: 'Khata'),
                  Tab(text: 'Sales (${_sales.length})'),
                ],
              ),
            ),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppColors.green,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _KhataTab(
                            customer: _customer,
                            entries: _entries,
                            hasBalance: hasBalance,
                            balance: balance,
                            onCredit: () => _showEntrySheet(
                                entryType: KhataEntryType.credit),
                            onPayment: () => _showEntrySheet(
                                entryType: KhataEntryType.payment),
                            onDelete: _deleteEntry,
                          ),
                          _SalesTab(
                              sales: _sales,
                              customerName: _customer.name),
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

// ── Khata tab ─────────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      children: [
        // ── Outstanding balance card ─────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: hasBalance ? AppColors.amberLight : AppColors.greenLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasBalance
                  ? const Color(0xFFEAD6AE)
                  : const Color(0xFFC7E4D5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasBalance ? Symbols.warning : Symbols.check_circle,
                    color: hasBalance ? AppColors.amber : AppColors.green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasBalance ? 'Outstanding balance' : 'All Clear',
                    style: instrument(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: hasBalance
                          ? AppColors.amberDark
                          : AppColors.greenDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                formatPkr(balance),
                style: mono(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: hasBalance ? AppColors.amberDark : AppColors.greenDark,
                  letterSpacing: -0.02,
                ),
              ),
              if (customer.phone.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Symbols.call,
                        size: 15,
                        color: hasBalance
                            ? AppColors.amber
                            : AppColors.green),
                    const SizedBox(width: 5),
                    Text(customer.phone,
                        style: mono(
                            fontSize: 12.5,
                            color: hasBalance
                                ? const Color(0xFF8A6A3A)
                                : AppColors.greenDark)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Action buttons ───────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onCredit,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Symbols.arrow_upward,
                          size: 19, color: Colors.white),
                      const SizedBox(width: 7),
                      Text('Give Credit',
                          style: instrument(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: onPayment,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Symbols.arrow_downward,
                          size: 19, color: Colors.white),
                      const SizedBox(width: 7),
                      Text('Payment',
                          style: instrument(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        // ── History header ───────────────────────────────────────────
        Row(
          children: [
            Text('History',
                style: bricolage(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.paperDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${entries.length}',
                  style: mono(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'No entries yet. Use the buttons above to add credit or record a payment.',
              textAlign: TextAlign.center,
              style: instrument(fontSize: 14, color: AppColors.muted),
            ),
          )
        else
          ...entries.map((entry) => _EntryTile(
                entry: entry,
                onDelete: () => onDelete(entry),
              )),
      ],
    );
  }
}

// ── Sales tab ─────────────────────────────────────────────────────────────────

class _SalesTab extends StatelessWidget {
  final List<Sale> sales;
  final String customerName;

  const _SalesTab({required this.sales, required this.customerName});

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.amberLight,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Symbols.receipt_long,
                  size: 32, color: AppColors.amber),
            ),
            const SizedBox(height: 12),
            Text('No sales yet',
                style: instrument(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink)),
            const SizedBox(height: 6),
            Text('Sales made to this customer will appear here',
                style: instrument(fontSize: 13, color: AppColors.muted)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      itemCount: sales.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) =>
          _SaleTile(sale: sales[i], customerName: customerName),
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

    final ({Color iconBg, Color iconColor, IconData icon, String label})
        method = switch (sale.paymentMethod) {
      PaymentMethod.cash => (
          iconBg: AppColors.greenLight,
          iconColor: AppColors.green,
          icon: Symbols.payments,
          label: 'Cash',
        ),
      PaymentMethod.khata => (
          iconBg: AppColors.amberLight,
          iconColor: AppColors.amber,
          icon: Symbols.account_balance_wallet,
          label: 'Full Khata',
        ),
      PaymentMethod.partial => (
          iconBg: AppColors.tealLight,
          iconColor: AppColors.teal,
          icon: Symbols.call_split,
          label: 'Partial',
        ),
    };

    return Material(
      color: AppColors.card,
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
                child: Icon(method.icon, color: method.iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateStr,
                        style: mono(fontSize: 12, color: AppColors.muted)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: method.iconBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(method.label,
                              style: instrument(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: method.iconColor)),
                        ),
                        if (sale.khataAmount > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${formatPkr(sale.khataAmount)} on credit',
                            style: mono(fontSize: 11, color: AppColors.amber),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                formatPkr(sale.totalAmount),
                style: mono(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Entry tile ────────────────────────────────────────────────────────────────

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
    final color = isCredit ? AppColors.red : AppColors.green;
    final bgColor = isCredit ? AppColors.redLight : AppColors.greenLight;
    final dt = DateTime.fromMillisecondsSinceEpoch(entry.timestamp);
    final dateStr = DateFormat('d MMM yyyy, h:mm a').format(dt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCredit ? Symbols.arrow_upward : Symbols.arrow_downward,
              color: color,
              size: 19,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isCredit ? 'Credit' : 'Payment',
                        style: instrument(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: color),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatPkr(entry.amount),
                      style:
                          mono(fontSize: 14, fontWeight: FontWeight.w700, color: color),
                    ),
                  ],
                ),
                if (entry.note != null && entry.note!.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(entry.note!,
                      style: instrument(fontSize: 12, color: AppColors.muted)),
                ],
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(dateStr,
                        style: mono(fontSize: 11, color: AppColors.mutedLight)),
                    if (entry.saleId != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _openSale(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.greenLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Symbols.receipt,
                                  size: 11, color: AppColors.green),
                              const SizedBox(width: 3),
                              Text('View Sale',
                                  style: instrument(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.green)),
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
            icon: const Icon(Symbols.delete_outline,
                color: AppColors.mutedLight, size: 20),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
