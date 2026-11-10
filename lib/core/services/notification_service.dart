import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  static Future<void> scheduleDailyReminder() async {
    const androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel',
      'Pengingat Harian',
      channelDescription: 'Pengingat untuk mencatat pengeluaran harian',
      importance: Importance.defaultImportance,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, 20, 0);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      1001,
      'Catat Keuangan Hari Ini 📝',
      'Sudah mencatat pengeluaran Anda hari ini? Buka DafMoney sekarang.',
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> showBudgetWarning({
    required String categoryName,
    required int percentage,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'budget_alert_channel',
      'Peringatan Anggaran',
      channelDescription: 'Pemberitahuan saat penggunaan anggaran mendekati limit',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    final isLimit = percentage >= 100;
    final title = isLimit ? '⚠️ Anggaran Habis!' : '🔔 Peringatan Anggaran';
    final body = isLimit
        ? 'Pengeluaran untuk kategori "$categoryName" telah mencapai $percentage% dari anggaran!'
        : 'Pengeluaran untuk kategori "$categoryName" sudah terpakai $percentage%.';

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}
