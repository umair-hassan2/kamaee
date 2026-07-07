import '../services/settings_service.dart';

String formatPkr(double amount) =>
    SettingsService().formatCurrency(amount);

String get pkrPrefix => SettingsService().currencyPrefix;

String formatCurrency(double amount) =>
    SettingsService().formatCurrency(amount);

String get currencyPrefix => SettingsService().currencyPrefix;
