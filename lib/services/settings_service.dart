import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const _shopNameKey = 'shop_name';
  static const _ownerNameKey = 'owner_name';
  static const _lowStockKey = 'low_stock_threshold';
  static const _currencyKey = 'currency_code';
  static const _paymentMethodsKey = 'payment_methods';

  AppSettings _settings = AppSettings.defaults;
  AppSettings get settings => _settings;

  int get lowStockThreshold => _settings.lowStockThreshold;
  String get currencyPrefix => _settings.currency.symbol;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _settings = AppSettings(
      shopName: prefs.getString(_shopNameKey) ?? '',
      ownerName: prefs.getString(_ownerNameKey) ?? '',
      lowStockThreshold: prefs.getInt(_lowStockKey) ?? 5,
      currency: CurrencyOption.fromCode(
        prefs.getString(_currencyKey) ?? CurrencyOption.pkr.code,
      ),
      paymentMethods: _decodePaymentMethods(prefs.getString(_paymentMethodsKey)),
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_shopNameKey, settings.shopName);
    await prefs.setString(_ownerNameKey, settings.ownerName);
    await prefs.setInt(_lowStockKey, settings.lowStockThreshold);
    await prefs.setString(_currencyKey, settings.currency.code);
    await prefs.setString(
      _paymentMethodsKey,
      jsonEncode(settings.paymentMethods.map((e) => e.toJson()).toList()),
    );
    _settings = settings;
  }

  String formatCurrency(double amount) {
    final format = NumberFormat.currency(
      locale: _settings.currency.locale,
      symbol: _settings.currency.symbol,
      decimalDigits: 0,
    );
    return format.format(amount);
  }

  bool isLowStock(int quantity) =>
      quantity > 0 && quantity <= _settings.lowStockThreshold;

  bool isOutOfStock(int quantity) => quantity <= 0;

  static List<ShopPaymentMethod> _decodePaymentMethods(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => ShopPaymentMethod.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
