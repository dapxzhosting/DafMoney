import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      final offset = DateTime.now().timeZoneOffset;
      final now = DateTime.now().toUtc();
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (tz.TZDateTime.from(now, loc).timeZoneOffset == offset) {
          tz.setLocalLocation(loc);
          break;
        }
      }
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  static const _reminderId = 1001;

  static const _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_reminder_channel',
      'Pengingat Harian',
      channelDescription: 'Pengingat untuk mencatat pengeluaran harian',
      importance: Importance.defaultImportance,
      priority: Priority.high,
    ),
  );

  static Future<void> scheduleDailyReminder({
    int hour = 20,
    int minute = 0,
    bool skipToday = false,
  }) async {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    if (skipToday || scheduledDate.isBefore(now)) {
      scheduledDate = DateTime(now.year, now.month, now.day + 1, hour, minute);
    }

    await _plugin.zonedSchedule(
      _reminderId,
      'Catat Keuangan Hari Ini',
      'Sudah mencatat pengeluaran Anda hari ini? Buka DafMoney sekarang.',
      tz.TZDateTime.from(scheduledDate, tz.local),
      _reminderDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelDailyReminder() => _plugin.cancel(_reminderId);

  static Future<void> showTestReminder() {
    return _plugin.show(
      1002,
      'Tes pengingat DafMoney',
      'Pengingat harian aktif. Notifikasi seperti ini yang akan Anda terima.',
      _reminderDetails,
    );
  }

  static Future<void> showBudgetWarning({
    required String categoryName,
    required int percentage,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'budget_alert_channel',
      'Peringatan Anggaran',
      channelDescription:
          'Pemberitahuan saat penggunaan anggaran mendekati limit',
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

  static const _infoDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'info_channel',
      'Info Aplikasi',
      channelDescription: 'Pemberitahuan umum dari DafMoney',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  static Future<void> showInfo({required String title, required String body}) {
    return _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      _infoDetails,
    );
  }

  static const _dueDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'due_channel',
      'Jatuh Tempo',
      channelDescription: 'Pengingat utang & piutang yang jatuh tempo',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static int idFor(String docId) => 100000 + (docId.hashCode & 0x0fffffff);

  static Future<void> scheduleOnce({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (!when.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      _dueDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancel(int id) => _plugin.cancel(id);
}
