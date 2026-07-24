import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database_helper.dart';
import '../models/sale.dart';
import '../models/transaction.dart';
import '../services/khata_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/receipt_pdf_generator.dart';
import 'return_screen.dart';

class SaleDetailScreen extends StatefulWidget {
  final Sale sale;
  final String? customerName;

  const SaleDetailScreen({
    super.key,
    required this.sale,
    this.customerName,
  });

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  final _db = DatabaseHelper();
  final _khataService = KhataService();
  late Sale _sale;
  List<SaleTransaction> _items = [];
  String? _resolvedCustomerName;
  bool _isLoading = true;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _sale = widget.sale;
    _resolvedCustomerName = widget.customerName;
    _loadData();
  }

  Future<void> _loadData() async {
    final items = await _db.getTransactionsForSale(_sale.id!);
    final freshSale = await _db.getSaleById(_sale.id!);
    String? customerName = _resolvedCustomerName;
    if (customerName == null && _sale.customerId != null) {
      final customer =
          await _khataService.getCustomerById(_sale.customerId!);
      customerName = customer?.name;
    }
    if (mounted) {
      setState(() {
        if (freshSale != null) _sale = freshSale;
        _items = items;
        _resolvedCustomerName = customerName;
        _isLoading = false;
      });
    }
  }

  Future<void> _sharePdf() async {
    setState(() => _sharing = true);
    try {
      final shopName = SettingsService().settings.shopName;
      final pdfBytes = await ReceiptPdfGenerator.generate(
        sale: _sale,
        items: _items,
        customerName: _resolvedCustomerName,
        shopName: shopName.isNotEmpty ? shopName : 'Kamaae',
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/receipt_${_sale.id}.pdf');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        text: _resolvedCustomerName != null
            ? 'Bill for $_resolvedCustomerName'
            : 'Your bill',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not share: $e'),
              backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(_sale.timestamp);
    final dateStr = DateFormat('d MMM yyyy, h:mm a').format(dt);

    Color methodColor;
    IconData methodIcon;
    String methodLabel;
    switch (_sale.paymentMethod) {
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
        methodLabel = 'Partial Payment';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Sale #${_sale.id}'),
        actions: [
          if (_sharing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: _isLoading ? null : _sharePdf,
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share Bill',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Meta info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 14, color: AppColors.muted),
                            const SizedBox(width: 6),
                            Text(dateStr,
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.muted)),
                          ],
                        ),
                        if (_resolvedCustomerName != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.person_outlined,
                                  size: 14, color: AppColors.muted),
                              const SizedBox(width: 6),
                              Text(_resolvedCustomerName!,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: methodColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(methodIcon, size: 14, color: methodColor),
                                  const SizedBox(width: 6),
                                  Text(methodLabel,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: methodColor)),
                                ],
                              ),
                            ),
                            if (_sale.isReturned) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.redLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Symbols.assignment_return,
                                        size: 13, color: AppColors.red),
                                    const SizedBox(width: 5),
                                    Text('Returned',
                                        style: instrument(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Items
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Items',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                                fontSize: 12)),
                        const SizedBox(height: 12),
                        ..._items.map(
                          (line) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text(line.itemName,
                                        style:
                                            const TextStyle(fontSize: 14))),
                                Text(
                                    '${line.quantity} × ${formatPkr(line.unitPrice)}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.muted)),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    formatPkr(line.revenue),
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 24),
                        if (_sale.discountAmount > 0) ...[
                          _Row(
                              label: 'Subtotal',
                              value: formatPkr(_sale.totalAmount +
                                  _sale.discountAmount),
                              color: AppColors.muted),
                          const SizedBox(height: 6),
                          _Row(
                              label: 'Discount',
                              value: '− ${formatPkr(_sale.discountAmount)}',
                              color: AppColors.danger),
                          const SizedBox(height: 6),
                        ],
                        _Row(
                            label: 'Total',
                            value: formatPkr(_sale.totalAmount),
                            bold: true),
                        if (_sale.paidAmount > 0 &&
                            _sale.paymentMethod !=
                                PaymentMethod.cash) ...[
                          const SizedBox(height: 6),
                          _Row(
                              label: 'Paid',
                              value: formatPkr(_sale.paidAmount),
                              color: AppColors.sell),
                        ],
                        if (_sale.khataAmount > 0) ...[
                          const SizedBox(height: 6),
                          _Row(
                              label: 'On Khata',
                              value: formatPkr(_sale.khataAmount),
                              color: AppColors.warning),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  OutlinedButton.icon(
                    onPressed: _sharing ? null : _sharePdf,
                    icon: _sharing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.share_outlined),
                    label: const Text('Share Bill via WhatsApp'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.4)),
                      foregroundColor: AppColors.primary,
                    ),
                  ),

                  if (!_sale.isReturned) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReturnScreen(
                                    sale: _sale,
                                    items: _items,
                                    customerName: _resolvedCustomerName,
                                  ),
                                ),
                              );
                              _loadData();
                            },
                      icon: const Icon(Symbols.assignment_return),
                      label: const Text('Process Return'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        side: BorderSide(
                            color: AppColors.amber.withValues(alpha: 0.5)),
                        foregroundColor: AppColors.amber,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _Row(
      {required this.label,
      required this.value,
      this.bold = false,
      this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 16 : 14,
      color: color,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}
