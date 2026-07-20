import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsService = SettingsService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _shopNameController;
  late final TextEditingController _ownerNameController;
  late final TextEditingController _lowStockController;
  late CurrencyOption _currency;
  late List<ShopPaymentMethod> _paymentMethods;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = _settingsService.settings;
    _shopNameController = TextEditingController(text: settings.shopName);
    _ownerNameController = TextEditingController(text: settings.ownerName);
    _lowStockController =
        TextEditingController(text: '${settings.lowStockThreshold}');
    _currency = settings.currency;
    _paymentMethods = List.from(settings.paymentMethods);
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      await _settingsService.save(
        AppSettings(
          shopName: _shopNameController.text.trim(),
          ownerName: _ownerNameController.text.trim(),
          lowStockThreshold: int.parse(_lowStockController.text.trim()),
          currency: _currency,
          paymentMethods: _paymentMethods,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _persistPaymentMethods(List<ShopPaymentMethod> methods) async {
    final current = _settingsService.settings;
    await _settingsService.save(current.copyWith(paymentMethods: methods));
  }

  void _showAddPaymentMethodSheet() {
    final labelController = TextEditingController();
    final urlController = TextEditingController();
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
                      color: AppColors.greenLight,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Symbols.qr_code_2,
                        color: AppColors.green, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text('Add Payment Method',
                      style: bricolage(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: labelController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: instrument(fontSize: 15),
                decoration: const InputDecoration(
                  labelText: 'Label *',
                  hintText: 'e.g. JazzCash, EasyPaisa, Meezan Bank',
                  prefixIcon: Icon(Symbols.label_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Label is required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: urlController,
                keyboardType: TextInputType.url,
                style: mono(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Payment URL *',
                  hintText: 'https://jazzcash.com.pk/...',
                  prefixIcon: Icon(Symbols.link),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'URL is required';
                  final uri = Uri.tryParse(v.trim());
                  if (uri == null || !uri.hasScheme) return 'Enter a valid URL';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final method = ShopPaymentMethod(
                    label: labelController.text.trim(),
                    url: urlController.text.trim(),
                  );
                  final updated = [..._paymentMethods, method];
                  setState(() => _paymentMethods = List.from(updated));
                  await _persistPaymentMethods(updated);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Add Method'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionHeader(
                icon: Icons.storefront_outlined,
                title: 'Shop Profile',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _shopNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Shop Name',
                  hintText: 'e.g. Hassan General Store',
                  prefixIcon: Icon(Icons.store_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ownerNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Owner Name',
                  hintText: 'e.g. Ahmed Hassan',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 28),
              const _SectionHeader(
                icon: Icons.tune_outlined,
                title: 'Preferences',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CurrencyOption>(
                initialValue: _currency,
                decoration: const InputDecoration(
                  labelText: 'Currency',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                items: CurrencyOption.values
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.code} (${c.symbol.trim()})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _currency = value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lowStockController,
                decoration: const InputDecoration(
                  labelText: 'Low Stock Warning Level',
                  hintText: 'Alert when quantity is at or below this',
                  prefixIcon: Icon(Icons.warning_amber_outlined),
                  helperText:
                      'Items with stock at or below this show a warning',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a threshold';
                  }
                  final parsed = int.tryParse(value.trim());
                  if (parsed == null || parsed < 0) {
                    return 'Enter a valid number (0 or more)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // ── Payment Methods ────────────────────────────────────────────
              Row(
                children: [
                  const _SectionHeader(
                    icon: Icons.qr_code_outlined,
                    title: 'Payment Methods',
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _showAddPaymentMethodSheet,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Customers will see QR codes for all methods in the payment statement PDF.',
                style: instrument(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              if (_paymentMethods.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.paperDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(Symbols.qr_code_2,
                          size: 32, color: AppColors.mutedLight),
                      const SizedBox(height: 8),
                      Text(
                        'No payment methods yet',
                        style: instrument(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add JazzCash, EasyPaisa, or any payment link.',
                        textAlign: TextAlign.center,
                        style: instrument(fontSize: 12, color: AppColors.mutedLight),
                      ),
                    ],
                  ),
                )
              else
                ...List.generate(_paymentMethods.length, (i) {
                  final method = _paymentMethods[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.greenLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Symbols.qr_code_2,
                              size: 20, color: AppColors.green),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                method.label,
                                style: instrument(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                method.url,
                                style: mono(
                                    fontSize: 11, color: AppColors.muted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Symbols.delete_outline,
                              size: 20, color: AppColors.mutedLight),
                          onPressed: () async {
                            final updated =
                                List<ShopPaymentMethod>.from(_paymentMethods)
                                  ..removeAt(i);
                            setState(() => _paymentMethods = updated);
                            await _persistPaymentMethods(updated);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 28),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
