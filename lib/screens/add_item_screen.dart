import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../database_helper.dart';
import '../models/item.dart';
import '../services/image_storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../widgets/item_photo_picker.dart';

class AddItemScreen extends StatefulWidget {
  final String barcode;

  const AddItemScreen({super.key, required this.barcode});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _imageStorage = ImageStorageService();
  File? _pendingPhoto;
  bool _photoRemoved = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final item = Item(
        barcode: widget.barcode,
        name: _nameController.text.trim(),
        purchasePrice: double.parse(_purchasePriceController.text.trim()),
        sellingPrice: double.parse(_sellingPriceController.text.trim()),
        quantity: int.parse(_quantityController.text.trim()),
      );

      final id = await DatabaseHelper().insertItem(item);
      String? photoPath;
      if (_pendingPhoto != null) {
        photoPath = await _imageStorage.saveItemPhoto(_pendingPhoto!, id);
        await DatabaseHelper()
            .updateItem(item.copyWith(id: id, photoPath: photoPath));
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
                  Text('Add New Item',
                      style: bricolage(
                          fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Barcode badge ────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 13),
                        decoration: BoxDecoration(
                          color: AppColors.greenLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFFC7E4D5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Symbols.qr_code_2,
                                color: AppColors.green, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Scanned code',
                                      style: instrument(
                                          fontSize: 11,
                                          color: AppColors.greenDark)),
                                  Text(widget.barcode,
                                      style: mono(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.greenDark)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Photo picker ─────────────────────────────────
                      ItemPhotoPicker(
                        currentPhotoPath: null,
                        pendingPhoto: _pendingPhoto,
                        photoRemoved: _photoRemoved,
                        onPhotoChanged: (file) => setState(() {
                          _pendingPhoto = file;
                          _photoRemoved = false;
                        }),
                        onPhotoRemoved: () => setState(() {
                          _pendingPhoto = null;
                          _photoRemoved = true;
                        }),
                      ),
                      const SizedBox(height: 20),

                      // ── Product name ──────────────────────────────────
                      _FieldLabel('Product name'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: instrument(fontSize: 15),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Symbols.label),
                          hintText: 'e.g. Tapal Danedar 200g',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter a name'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // ── Prices ────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel('Purchase price'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _purchasePriceController,
                                  style: mono(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: InputDecoration(
                                    prefixText: '$currencyPrefix ',
                                    prefixStyle: mono(
                                        fontSize: 13,
                                        color: AppColors.muted),
                                    hintText: '0',
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Required';
                                    }
                                    final n = double.tryParse(v.trim());
                                    if (n == null || n <= 0) return 'Invalid';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel('Selling price'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _sellingPriceController,
                                  style: mono(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.greenDark),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: InputDecoration(
                                    prefixText: '$currencyPrefix ',
                                    prefixStyle: mono(
                                        fontSize: 13,
                                        color: AppColors.green),
                                    hintText: '0',
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: AppColors.green, width: 2),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: AppColors.green),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Required';
                                    }
                                    final n = double.tryParse(v.trim());
                                    if (n == null || n <= 0) return 'Invalid';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Quantity ──────────────────────────────────────
                      _FieldLabel('Initial stock quantity'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _quantityController,
                        style: mono(fontSize: 15, fontWeight: FontWeight.w600),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Symbols.inventory),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter a quantity';
                          }
                          final n = int.tryParse(v.trim());
                          if (n == null || n <= 0) {
                            return 'Enter a valid quantity';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),

            // ── Save button ───────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, MediaQuery.of(context).padding.bottom + 22),
              child: GestureDetector(
                onTap: _isSaving ? null : _saveItem,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Symbols.check,
                                  size: 21, color: Colors.white),
                              const SizedBox(width: 8),
                              Text('Save to Inventory',
                                  style: instrument(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ],
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

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: instrument(
            fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted));
  }
}
