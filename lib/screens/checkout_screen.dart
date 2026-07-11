import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../models/transaction.dart';
import '../services/cart_service.dart';
import '../services/khata_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'receipt_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<SaleTransaction> items;
  final double total;

  const CheckoutScreen({
    super.key,
    required this.items,
    required this.total,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _cartService = CartService();
  final _khataService = KhataService();

  PaymentMethod _method = PaymentMethod.cash;
  final _paidController = TextEditingController();
  bool _isLoading = false;

  // Customer picker state
  List<Customer> _customers = [];
  Customer? _selectedCustomer;
  bool _customersLoaded = false;

  double get _paid {
    if (_method == PaymentMethod.cash) return widget.total;
    if (_method == PaymentMethod.khata) return 0;
    return double.tryParse(_paidController.text) ?? 0;
  }

  double get _khata => (widget.total - _paid).clamp(0.0, widget.total);

  bool get _needsCustomer =>
      _method == PaymentMethod.khata || _method == PaymentMethod.partial;

  bool get _canConfirm {
    if (_needsCustomer && _selectedCustomer == null) return false;
    if (_method == PaymentMethod.partial) {
      final paid = double.tryParse(_paidController.text) ?? 0;
      return paid > 0 && paid < widget.total;
    }
    return true;
  }

  @override
  void dispose() {
    _paidController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    if (_customersLoaded) return;
    final customers = await _khataService.getCustomers();
    if (!mounted) return;
    setState(() {
      _customers = customers;
      _customersLoaded = true;
    });
  }

  void _onMethodChanged(PaymentMethod method) {
    setState(() {
      _method = method;
      if (!_needsCustomer) _selectedCustomer = null;
    });
    if (_needsCustomer) _loadCustomers();
  }

  Future<void> _pickCustomer() async {
    await _loadCustomers();
    if (!mounted) return;

    final picked = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CustomerPickerSheet(
        customers: _customers,
        selected: _selectedCustomer,
        onNewCustomer: _createCustomer,
      ),
    );
    if (picked != null) {
      setState(() => _selectedCustomer = picked);
    }
  }

  Future<Customer?> _createCustomer() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    Customer? created;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final id = await _khataService.addCustomer(Customer(
                name: name,
                phone: phoneCtrl.text.trim(),
                createdAt: DateTime.now().millisecondsSinceEpoch,
              ));
              created = Customer(
                id: id,
                name: name,
                phone: phoneCtrl.text.trim(),
                createdAt: DateTime.now().millisecondsSinceEpoch,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (created != null) {
      // Refresh customer list
      final customers = await _khataService.getCustomers();
      if (mounted) setState(() => _customers = customers);
    }
    return created;
  }

  Future<void> _confirm() async {
    if (_isLoading || !_canConfirm) return;
    setState(() => _isLoading = true);
    try {
      final sale = await _cartService.completeSale(
        paymentMethod: _method,
        paidAmount: _paid,
        customerId: _selectedCustomer?.id,
      );
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptScreen(
            sale: sale,
            items: widget.items,
            customerName: _selectedCustomer?.name,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('StateError: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Order summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Summary',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                ),
                const SizedBox(height: 12),
                ...widget.items.map(
                  (line) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${line.itemName} × ${line.quantity}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          formatPkr(line.revenue),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Text(
                      formatPkr(widget.total),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Payment Method',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),

          _PaymentOption(
            label: 'Cash',
            subtitle: 'Full amount paid now',
            icon: Icons.payments_outlined,
            color: AppColors.sell,
            selected: _method == PaymentMethod.cash,
            onTap: () => _onMethodChanged(PaymentMethod.cash),
          ),
          const SizedBox(height: 10),
          _PaymentOption(
            label: 'Khata (Udhaar)',
            subtitle: 'Full amount on credit — requires customer',
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.warning,
            selected: _method == PaymentMethod.khata,
            onTap: () => _onMethodChanged(PaymentMethod.khata),
          ),
          const SizedBox(height: 10),
          _PaymentOption(
            label: 'Partial Payment',
            subtitle: 'Some cash now, rest on credit — requires customer',
            icon: Icons.call_split_outlined,
            color: AppColors.accent,
            selected: _method == PaymentMethod.partial,
            onTap: () => _onMethodChanged(PaymentMethod.partial),
          ),

          // Customer picker (shown for khata & partial)
          if (_needsCustomer) ...[
            const SizedBox(height: 20),
            Text(
              'Customer',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickCustomer,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedCustomer != null
                        ? AppColors.primary
                        : Colors.grey.shade300,
                    width: _selectedCustomer != null ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _selectedCustomer == null
                          ? const Text(
                              'Select customer…',
                              style: TextStyle(color: AppColors.muted),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedCustomer!.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                if (_selectedCustomer!.phone.isNotEmpty)
                                  Text(
                                    _selectedCustomer!.phone,
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.muted),
                                  ),
                              ],
                            ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Partial amount field
          if (_method == PaymentMethod.partial) ...[
            const SizedBox(height: 20),
            Text(
              'Amount Paid Now',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _paidController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '0.00',
                prefixText: 'PKR ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_paidController.text.isNotEmpty && _khata > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${formatPkr(_khata)} will be added to ${_selectedCustomer?.name ?? "customer"}'s khata',
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

          const SizedBox(height: 32),

          FilledButton(
            onPressed: (_isLoading || !_canConfirm) ? null : _confirm,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sell,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _method == PaymentMethod.cash
                        ? 'Confirm Sale · ${formatPkr(widget.total)}'
                        : _method == PaymentMethod.khata
                            ? 'Record on Khata · ${formatPkr(widget.total)}'
                            : 'Confirm · ${formatPkr(_paid)} now + ${formatPkr(_khata)} khata',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),

          if (_needsCustomer && _selectedCustomer == null) ...[
            const SizedBox(height: 8),
            const Text(
              'Select a customer to continue',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _CustomerPickerSheet extends StatefulWidget {
  final List<Customer> customers;
  final Customer? selected;
  final Future<Customer?> Function() onNewCustomer;

  const _CustomerPickerSheet({
    required this.customers,
    required this.selected,
    required this.onNewCustomer,
  });

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  String _query = '';

  List<Customer> get _filtered => widget.customers
      .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Customer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final created = await widget.onNewCustomer();
                    if (created != null && context.mounted) {
                      Navigator.pop(context, created);
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search…',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: _filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No customers found',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final c = _filtered[i];
                      final isSelected = c.id == widget.selected?.id;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.12),
                          child: Text(
                            c.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(c.name,
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: c.phone.isNotEmpty ? Text(c.phone) : null,
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: AppColors.primary)
                            : null,
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: selected ? color : null,
                      )),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: color, size: 22)
            else
              Icon(Icons.circle_outlined,
                  color: Colors.grey.shade300, size: 22),
          ],
        ),
      ),
    );
  }
}
