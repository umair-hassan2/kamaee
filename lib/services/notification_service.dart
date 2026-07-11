import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _lowStockChannelId = 'low_stock';
  static const _dailyChannelId = 'daily_summary';
  static const _dailySummaryId = 1;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    _setLocalTimezone();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    _initialized = true;
  }

  void _setLocalTimezone() {
    try {
      final offsetHours = DateTime.now().timeZoneOffset.inHours;
      final name = offsetHours >= 0
          ? 'Etc/GMT-$offsetHours'
          : 'Etc/GMT+${offsetHours.abs()}';
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<void> showLowStockAlert(String itemName, int quantity) async {
    if (!_initialized) return;
    const androidDetails = AndroidNotificationDetails(
      _lowStockChannelId,
      'Low Stock Alerts',
      channelDescription: 'Alerts when inventory items are running low',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      100 + itemName.hashCode.abs() % 900,
      quantity == 0 ? 'Out of Stock: $itemName' : 'Low Stock: $itemName',
      quantity == 0
          ? '$itemName is out of stock'
          : 'Only $quantity unit${quantity == 1 ? "" : "s"} remaining',
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> scheduleDailySummary({
    required double revenue,
    required double profit,
    required int lowStockCount,
  }) async {
    if (!_initialized) return;
    await _plugin.cancel(_dailySummaryId);
    const androidDetails = AndroidNotificationDetails(
      _dailyChannelId,
      'Daily Summary',
      channelDescription: 'End-of-day business summary',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    final String body;
    if (revenue > 0) {
      body = 'Revenue: Rs ${revenue.toStringAsFixed(0)}  •  '
          'Profit: Rs ${profit.toStringAsFixed(0)}'
          '${lowStockCount > 0 ? "  •  $lowStockCount low stock" : ""}';
    } else {
      body = lowStockCount > 0
          ? '$lowStockCount item${lowStockCount == 1 ? "" : "s"} need restocking'
          : 'Tap to view your shop summary';
    }
    final scheduledTime = _nextNinePM();
    await _plugin.zonedSchedule(
      _dailySummaryId,
      'Daily Summary',
      body,
      scheduledTime,
      const NotificationDetails(android: androidDetails),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextNinePM() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 21);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
