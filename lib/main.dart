import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/cart_service.dart';
import 'services/finance_service.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'services/shop_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await SettingsService().load();
  await NotificationService().init();
  await CartService().init();
  ShopService().init(); // fire-and-forget; Firestore queues if offline
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
      home: const SplashScreen(),
    );
  }
}
