import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/bill_formatter.dart';
import '../utils/currency_formatter.dart';
import '../utils/whatsapp_share.dart';

class CreateBillScreen extends StatefulWidget {
  const CreateBillScreen({super.key});

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  final _customerNameController = TextEditingController();
  final _paidController = TextEditingController();
  final List<_BillItemRow> _rows = [];

  double get _total => _rows.fold(0, (sum, r) => sum + r.lineTotal);
  double get _paid {
    final v = double.tryParse(_paidController.text.trim());
    return v ?? _total;
  }

  double get _balance => (_total - _paid).clamp(0, double.infinity);

  @override
  void initState() {
    super.initState();
    _rows.add(_BillItemRow());
    _paidController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _paidController.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() => _rows.add(_BillItemRow()));
  }

  void _removeRow(int index) {
    if (_rows.length == 1) return;
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  Future<void> _shareOnWhatsApp() async {
    final items = _rows
        .where((r) => r.name.isNotEmpty && r.qty > 0 && r.unitPrice > 0)
        .map((r) => BillItem(name: r.name, qty: r.qty, unitPrice: r.unitPrice))
        .toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item to the bill.')),
      );
      return;
    }

    final text = BillFormatter.format(
      items: items,
      total: _total,
      paid: _paid,
      balance: _balance,
      customerName: _customerNameController.text.trim().isEmpty
          ? null
          : _customerNameController.text.trim(),
    );

    await WhatsAppShare.share(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Bill'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _customerNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name (optional)',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Item',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 48,
                      child: Text(
                        'Qty',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Price',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    SizedBox(width: 36),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(_rows.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ItemRowWidget(
                      row: _rows[i],
                      onChanged: () => setState(() {}),
                      onRemove: _rows.length > 1 ? () => _removeRow(i) : null,
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(color: AppColors.muted)),
                          Text(
                            formatPkr(_total),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _paidController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Paid Now',
                          prefixIcon: const Icon(Icons.payments_outlined),
                          hintText: formatPkr(_total),
                        ),
                      ),
                      if (_balance > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 16,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Balance on Khata: ${formatPkr(_balance)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _shareOnWhatsApp,
                icon: const Icon(Icons.send),
                label: const Text('Share on WhatsApp'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillItemRow {
  final nameController = TextEditingController();
  final qtyController = TextEditingController(text: '1');
  final priceController = TextEditingController();

  String get name => nameController.text.trim();
  int get qty => int.tryParse(qtyController.text.trim()) ?? 0;
  double get unitPrice => double.tryParse(priceController.text.trim()) ?? 0;
  double get lineTotal => qty * unitPrice;

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }
}

class _ItemRowWidget extends StatelessWidget {
  final _BillItemRow row;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const _ItemRowWidget({
    required this.row,
    required this.onChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: TextField(
            controller: row.nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Item name',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          child: TextField(
            controller: row.qtyController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: '1',
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextField(
            controller: row.priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '0',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 32,
          child: IconButton(
            onPressed: onRemove,
            icon: Icon(
              Icons.remove_circle_outline,
              size: 20,
              color: onRemove != null ? AppColors.danger : Colors.grey.shade300,
            ),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
