import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/customer.dart';
import '../services/khata_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'customer_detail_screen.dart';

class KhataScreen extends StatefulWidget {
  const KhataScreen({super.key});

  @override
  State<KhataScreen> createState() => _KhataScreenState();
}

class _KhataScreenState extends State<KhataScreen> {
  final _khataService = KhataService();
  List<Customer> _customers = [];
  double _totalOutstanding = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _khataService.getCustomers(),
      _khataService.getTotalOutstanding(),
    ]);
    if (!mounted) return;
    setState(() {
      _customers = results[0] as List<Customer>;
      _totalOutstanding = results[1] as double;
      _isLoading = false;
    });
  }

  void _showAddCustomerSheet() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
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
              Text('Add Customer',
                  style: bricolage(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: instrument(fontSize: 15),
                decoration: const InputDecoration(
                  labelText: 'Customer Name *',
                  hintText: 'e.g. Ahmed Bhai',
                  prefixIcon: Icon(Symbols.person),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: instrument(fontSize: 15),
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  hintText: '03XX-XXXXXXX',
                  prefixIcon: Icon(Symbols.phone),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final customer = Customer(
                    name: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                    createdAt: DateTime.now().millisecondsSinceEpoch,
                  );
                  await _khataService.addCustomer(customer);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  await _loadData();
                },
                child: const Text('Add Customer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Customer',
            style: bricolage(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text(
          'Delete ${customer.name} and all their khata entries? This cannot be undone.',
          style: instrument(fontSize: 14),
        ),
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
      await _khataService.deleteCustomer(customer.id!);
      await _loadData();
    }
  }

  int get _withBalance => _customers.where((c) => c.balance > 0).length;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

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
                    Text('Khata / Udhaar',
                        style: bricolage(
                            fontSize: 28, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),

                    // ── Hero card ────────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Symbols.account_balance_wallet,
                                  size: 18,
                                  color: Color(0xFFE0A64E),
                                  fill: 1),
                              const SizedBox(width: 10),
                              Text(
                                'TOTAL OUTSTANDING',
                                style: instrument(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkMuted,
                                  letterSpacing: 0.14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formatPkr(_totalOutstanding),
                            style: mono(
                              fontSize: 38,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onDark,
                              letterSpacing: -0.02,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Across $_withBalance ${_withBalance == 1 ? 'customer' : 'customers'} with a balance',
                            style: instrument(
                                fontSize: 12.5, color: AppColors.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Text(
                          'CUSTOMERS',
                          style: instrument(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                            letterSpacing: 0.14,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_customers.length} total',
                          style: instrument(fontSize: 12.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_customers.isEmpty)
              SliverFillRemaining(
                child: Center(
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
                        child: const Icon(Symbols.people,
                            size: 36, color: AppColors.amber),
                      ),
                      const SizedBox(height: 16),
                      Text('No customers yet.',
                          style: instrument(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink)),
                      const SizedBox(height: 6),
                      Text('Tap + to add your first customer.',
                          style: instrument(
                              fontSize: 14, color: AppColors.muted)),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final customer = _customers[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CustomerCard(
                          customer: customer,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CustomerDetailScreen(customer: customer),
                              ),
                            );
                            await _loadData();
                          },
                          onDelete: () => _deleteCustomer(customer),
                        ),
                      );
                    },
                    childCount: _customers.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomerSheet,
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Symbols.person_add),
      ),
    );
  }
}

// ── Customer card ─────────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CustomerCard({
    required this.customer,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasBalance = customer.balance > 0;
    final initial = customer.name.isNotEmpty
        ? customer.name[0].toUpperCase()
        : '?';

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: hasBalance ? AppColors.amberLight : AppColors.greenLight,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: bricolage(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: hasBalance ? AppColors.amber : AppColors.green,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.name,
                        style: instrument(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    if (customer.phone.isNotEmpty)
                      Text(customer.phone,
                          style: mono(
                              fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatPkr(customer.balance),
                    style: mono(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: hasBalance ? AppColors.red : AppColors.green,
                    ),
                  ),
                  Text(
                    hasBalance ? 'owes' : 'cleared',
                    style: instrument(
                      fontSize: 11,
                      color: hasBalance
                          ? AppColors.red.withValues(alpha: 0.7)
                          : AppColors.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Symbols.delete_outline,
                    size: 20, color: AppColors.mutedLight),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
