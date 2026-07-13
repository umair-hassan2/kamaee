import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'screens/main_shell.dart';
import 'services/cart_service.dart';
import 'services/finance_service.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService().load();
  await NotificationService().init();
  await CartService().init();
  _scheduleDailySummary();
  runApp(const MyApp());
}

Future<void> _scheduleDailySummary() async {
  try {
    final finance = FinanceService();
    final summary = await finance.getTodaySummary();
    final items = await DatabaseHelper().getAllItems();
    final threshold = SettingsService().lowStockThreshold;
    final lowCount =
        items.where((i) => i.quantity > 0 && i.quantity <= threshold).length;
    await NotificationService().scheduleDailySummary(
      revenue: summary.revenue,
      profit: summary.profit,
      lowStockCount: lowCount,
    );
  } catch (_) {}
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kamaae',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const MainShell(),
    );
  }
}
