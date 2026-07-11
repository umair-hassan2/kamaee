import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer.dart';
import '../models/khata_entry.dart';
import '../services/khata_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final _khataService = KhataService();
  late Customer _customer;
  List<KhataEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _khataService.getCustomerById(_customer.id!),
      _khataService.getEntriesForCustomer(_customer.id!),
    ]);
    if (!mounted) return;
    setState(() {
      _customer = (results[0] as Customer?) ?? _customer;
      _entries = results[1] as List<KhataEntry>;
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
          20,
          20,
          20,
          20 + MediaQuery.of(ctx).viewInsets.bottom,
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
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount (Rs) *',
                  hintText: '0',
                  border: const OutlineInputBorder(),
                  prefixText: 'Rs ',
                  prefixIcon: Icon(
                    Icons.currency_rupee,
                    color: isCredit ? AppColors.danger : AppColors.sell,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Amount is required';
                  }
                  final amount = double.tryParse(v.trim());
                  if (amount == null || amount <= 0) {
                    return 'Enter a valid amount';
                  }
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
        content: const Text(
          'Delete this khata entry? This cannot be undone.',
        ),
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
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
                              color:
                                  hasBalance ? AppColors.warning : AppColors.sell,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              hasBalance ? 'Outstanding Balance' : 'All Clear',
                              style: TextStyle(
                                color: hasBalance
                                    ? AppColors.warning
                                    : AppColors.sell,
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
                            color: hasBalance
                                ? AppColors.warning
                                : AppColors.sell,
                            letterSpacing: -1,
                          ),
                        ),
                        if (_customer.phone.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone_outlined,
                                size: 14,
                                color: AppColors.muted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _customer.phone,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _showEntrySheet(
                            entryType: KhataEntryType.credit,
                          ),
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
                          onPressed: () => _showEntrySheet(
                            entryType: KhataEntryType.payment,
                          ),
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
                  // Transaction History Header
                  Row(
                    children: [
                      const Text(
                        'History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_entries.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_entries.isEmpty)
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
                    ...(_entries.map((entry) => _EntryTile(
                          entry: entry,
                          onDelete: () => _deleteEntry(entry),
                        ))),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final KhataEntry entry;
  final VoidCallback onDelete;

  const _EntryTile({required this.entry, required this.onDelete});

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
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCredit
                  ? Icons.arrow_upward_outlined
                  : Icons.arrow_downward_outlined,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
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
                    Expanded(
                      child: Text(
                        formatPkr(entry.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                if (entry.note != null && entry.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.note!,
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.grey.shade400),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
