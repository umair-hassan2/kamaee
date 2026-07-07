enum CurrencyOption {
  pkr('PKR', 'Rs ', 'en_PK'),
  usd('USD', '\$', 'en_US'),
  gbp('GBP', '£', 'en_GB'),
  aed('AED', 'AED ', 'en_AE'),
  sar('SAR', 'SAR ', 'ar_SA');

  const CurrencyOption(this.code, this.symbol, this.locale);

  final String code;
  final String symbol;
  final String locale;

  static CurrencyOption fromCode(String code) {
    return CurrencyOption.values.firstWhere(
      (c) => c.code == code,
      orElse: () => CurrencyOption.pkr,
    );
  }
}

class AppSettings {
  final String shopName;
  final String ownerName;
  final int lowStockThreshold;
  final CurrencyOption currency;

  const AppSettings({
    this.shopName = '',
    this.ownerName = '',
    this.lowStockThreshold = 5,
    this.currency = CurrencyOption.pkr,
  });

  static const defaults = AppSettings();

  AppSettings copyWith({
    String? shopName,
    String? ownerName,
    int? lowStockThreshold,
    CurrencyOption? currency,
  }) {
    return AppSettings(
      shopName: shopName ?? this.shopName,
      ownerName: ownerName ?? this.ownerName,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      currency: currency ?? this.currency,
    );
  }
}
