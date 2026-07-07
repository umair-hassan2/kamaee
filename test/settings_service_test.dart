import 'package:flutter_test/flutter_test.dart';
import 'package:kamaae/models/app_settings.dart';
import 'package:kamaae/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads defaults when no preferences saved', () async {
    final service = SettingsService();
    await service.load();

    expect(service.settings.shopName, '');
    expect(service.settings.lowStockThreshold, 5);
    expect(service.settings.currency, CurrencyOption.pkr);
  });

  test('persists and reloads settings', () async {
    final service = SettingsService();
    await service.save(
      const AppSettings(
        shopName: 'Test Shop',
        ownerName: 'Ahmed',
        lowStockThreshold: 10,
        currency: CurrencyOption.usd,
      ),
    );

    final reloaded = SettingsService();
    await reloaded.load();

    expect(reloaded.settings.shopName, 'Test Shop');
    expect(reloaded.settings.ownerName, 'Ahmed');
    expect(reloaded.settings.lowStockThreshold, 10);
    expect(reloaded.settings.currency, CurrencyOption.usd);
    expect(reloaded.formatCurrency(100), contains('\$'));
  });

  test('isLowStock respects threshold', () async {
    final service = SettingsService();
    await service.save(const AppSettings(lowStockThreshold: 3));

    expect(service.isLowStock(3), isTrue);
    expect(service.isLowStock(4), isFalse);
    expect(service.isOutOfStock(0), isTrue);
  });
}
