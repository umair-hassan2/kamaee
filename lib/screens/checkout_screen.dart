import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
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
  final _discountController = TextEditingController();
  bool _isPercent = true;
  bool _isLoading = false;

  List<Customer> _customers = [];
  Customer? _selectedCustomer;
  bool _customersLoaded = false;

  double get _discountAmount {
    final raw = double.tryParse(_discountController.text) ?? 0;
    if (raw <= 0) return 0;
    if (_isPercent) return (raw / 100 * widget.total).clamp(0.0, widget.total);
    return raw.clamp(0.0, widget.total);
  }

  double get _effectiveTotal => widget.total - _discountAmount;

  double get _paid {
    if (_method == PaymentMethod.cash) return _effectiveTotal;
    if (_method == PaymentMethod.khata) return 0;
    return double.tryParse(_paidController.text) ?? 0;
  }

  double get _khata => (_effectiveTotal - _paid).clamp(0.0, _effectiveTotal);

  bool get _needsCustomer =>
      _method == PaymentMethod.khata || _method == PaymentMethod.partial;

  bool get _canConfirm {
    if (_needsCustomer && _selectedCustomer == null) return false;
    if (_method == PaymentMethod.partial) {
      final paid = double.tryParse(_paidController.text) ?? 0;
      return paid > 0 && paid < _effectiveTotal;
    }
    return true;
  }

  @override
  void dispose() {
    _paidController.dispose();
    _discountController.dispose();
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
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CustomerPickerSheet(
        customers: _customers,
        selected: _selectedCustomer,
        onNewCustomer: _createCustomer,
      ),
    );
    if (picked != null) setState(() => _selectedCustomer = picked);
  }

  Future<Customer?> _createCustomer() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    Customer? created;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New Customer',
            style: bricolage(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: instrument(fontSize: 15),
              decoration: const InputDecoration(
                labelText: 'Name *',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: instrument(fontSize: 15),
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
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
        discountAmount: _discountAmount,
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
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Symbols.arrow_back,
                        size: 24, color: AppColors.ink),
                  ),
                  const SizedBox(width: 8),
                  Text('Checkout',
                      style: bricolage(
                          fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // ── Order summary ────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.paperDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ORDER SUMMARY',
                          style: instrument(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                            letterSpacing: 0.12,
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
                                    style: instrument(
                                        fontSize: 14, color: AppColors.secondary),
                                  ),
                                ),
                                Text(
                                  formatPkr(line.revenue),
                                  style: mono(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.ink),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_discountAmount > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text('Subtotal',
                                    style: instrument(
                                        fontSize: 13, color: AppColors.muted)),
                              ),
                              Text(
                                formatPkr(widget.total),
                                style: mono(
                                    fontSize: 13, color: AppColors.muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text('Discount',
                                    style: instrument(
                                        fontSize: 13, color: AppColors.red)),
                              ),
                              Text(
                                '− ${formatPkr(_discountAmount)}',
                                style: mono(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.red),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Divider(color: AppColors.borderDark, height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text('Total',
                                  style: instrument(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink)),
                            ),
                            Text(
                              formatPkr(_effectiveTotal),
                              style: mono(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Discount ─────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _discountAmount > 0
                            ? AppColors.green
                            : AppColors.border,
                        width: _discountAmount > 0 ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        _DiscountToggle(
                          label: '%',
                          selected: _isPercent,
                          onTap: () => setState(() => _isPercent = true),
                        ),
                        const SizedBox(width: 6),
                        _DiscountToggle(
                          label: 'PKR',
                          selected: !_isPercent,
                          onTap: () => setState(() => _isPercent = false),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _discountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}')),
                            ],
                            style: mono(
                                fontSize: 15, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText:
                                  _isPercent ? 'Discount %' : 'Discount amt',
                              hintStyle: instrument(
                                  fontSize: 13,
                                  color: AppColors.mutedLight),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              filled: false,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (_discountAmount > 0)
                          Text(
                            '− ${formatPkr(_discountAmount)}',
                            style: instrument(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.red),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  Text(
                    'PAYMENT METHOD',
                    style: instrument(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                      letterSpacing: 0.12,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _PaymentOption(
                    label: 'Cash',
                    subtitle: 'Full amount paid now',
                    icon: Symbols.payments,
                    iconBg: _method == PaymentMethod.cash
                        ? AppColors.green
                        : AppColors.greenLight,
                    iconColor: _method == PaymentMethod.cash
                        ? Colors.white
                        : AppColors.green,
                    selected: _method == PaymentMethod.cash,
                    onTap: () => _onMethodChanged(PaymentMethod.cash),
                  ),
                  const SizedBox(height: 10),
                  _PaymentOption(
                    label: 'Khata (Udhaar)',
                    subtitle: 'Full amount on credit · needs customer',
                    icon: Symbols.account_balance_wallet,
                    iconBg: _method == PaymentMethod.khata
                        ? AppColors.amber
                        : AppColors.amberLight,
                    iconColor: _method == PaymentMethod.khata
                        ? Colors.white
                        : AppColors.amber,
                    selected: _method == PaymentMethod.khata,
                    onTap: () => _onMethodChanged(PaymentMethod.khata),
                  ),
                  const SizedBox(height: 10),
                  _PaymentOption(
                    label: 'Partial Payment',
                    subtitle: 'Some cash now, rest on credit',
                    icon: Symbols.call_split,
                    iconBg: _method == PaymentMethod.partial
                        ? AppColors.teal
                        : AppColors.tealLight,
                    iconColor: _method == PaymentMethod.partial
                        ? Colors.white
                        : AppColors.teal,
                    selected: _method == PaymentMethod.partial,
                    onTap: () => _onMethodChanged(PaymentMethod.partial),
                  ),

                  if (_needsCustomer) ...[
                    const SizedBox(height: 22),
                    Text(
                      'CUSTOMER',
                      style: instrument(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                        letterSpacing: 0.12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickCustomer,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _selectedCustomer != null
                                ? AppColors.green
                                : AppColors.border,
                            width: _selectedCustomer != null ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: AppColors.greenLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Symbols.person,
                                  color: AppColors.green, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _selectedCustomer == null
                                  ? Text('Select customer…',
                                      style: instrument(
                                          fontSize: 14,
                                          color: AppColors.muted))
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(_selectedCustomer!.name,
                                            style: instrument(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600)),
                                        if (_selectedCustomer!.phone.isNotEmpty)
                                          Text(_selectedCustomer!.phone,
                                              style: instrument(
                                                  fontSize: 12,
                                                  color: AppColors.muted)),
                                      ],
                                    ),
                            ),
                            const Icon(Symbols.chevron_right,
                                color: AppColors.mutedLight),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (_method == PaymentMethod.partial) ...[
                    const SizedBox(height: 22),
                    Text(
                      'AMOUNT PAID NOW',
                      style: instrument(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                        letterSpacing: 0.12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _paidController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      onChanged: (_) => setState(() {}),
                      style: mono(fontSize: 15, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixText: 'PKR ',
                        prefixStyle: instrument(fontSize: 14, color: AppColors.muted),
                      ),
                    ),
                    if (_paidController.text.isNotEmpty && _khata > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.amberLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.amber.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Symbols.info,
                                color: AppColors.amber, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "${formatPkr(_khata)} will be added to ${_selectedCustomer?.name ?? 'customer'}'s khata",
                                style: instrument(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.amberDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),

            // ── Confirm button ────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, MediaQuery.of(context).padding.bottom + 22),
              child: GestureDetector(
                onTap: (_isLoading || !_canConfirm) ? null : _confirm,
                child: AnimatedOpacity(
                  opacity: _canConfirm ? 1.0 : 0.5,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : Text(
                              _method == PaymentMethod.cash
                                  ? 'Confirm Sale · ${formatPkr(_effectiveTotal)}'
                                  : _method == PaymentMethod.khata
                                      ? 'Record on Khata · ${formatPkr(_effectiveTotal)}'
                                      : 'Confirm · ${formatPkr(_paid)} now + ${formatPkr(_khata)} khata',
                              style: instrument(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Customer picker sheet ─────────────────────────────────────────────────────

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
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Select Customer',
                      style: bricolage(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final created = await widget.onNewCustomer();
                    if (created != null && context.mounted) {
                      Navigator.pop(context, created);
                    }
                  },
                  icon: const Icon(Symbols.add, size: 18),
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
              style: instrument(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search…',
                prefixIcon: Icon(Symbols.search, size: 20),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: _filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('No customers found',
                        style: instrument(
                            fontSize: 14, color: AppColors.muted)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final c = _filtered[i];
                      final isSelected = c.id == widget.selected?.id;
                      final initial = c.name.isNotEmpty
                          ? c.name[0].toUpperCase()
                          : '?';
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.amberLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(initial,
                                style: bricolage(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.amber)),
                          ),
                        ),
                        title: Text(c.name,
                            style: instrument(
                                fontSize: 15, fontWeight: FontWeight.w500)),
                        subtitle: c.phone.isNotEmpty ? Text(c.phone) : null,
                        trailing: isSelected
                            ? const Icon(Symbols.check_circle,
                                color: AppColors.green, fill: 1)
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

// ── Discount toggle chip ──────────────────────────────────────────────────────

class _DiscountToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DiscountToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.paperDark,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: instrument(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.paper : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

// ── Payment option ────────────────────────────────────────────────────────────

class _PaymentOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
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
          color: selected
              ? (iconColor == Colors.white
                  ? iconBg.withValues(alpha: 0.08)
                  : iconBg.withValues(alpha: 0.12))
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? iconBg : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: instrument(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: instrument(
                          fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            selected
                ? const Icon(Symbols.check_circle,
                    color: AppColors.green, fill: 1, size: 24)
                : const Icon(Symbols.radio_button_unchecked,
                    color: AppColors.mutedLight, size: 22),
          ],
        ),
      ),
    );
  }
}
