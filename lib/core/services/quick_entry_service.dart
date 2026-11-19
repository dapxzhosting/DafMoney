import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/entry_type.dart';
import 'quick_entry_saver.dart';

/// Dipanggil Android saat tombol notifikasi ditekan sementara app TERTUTUP.
/// Harus top-level dan diberi `vm:entry-point`.
@pragma('vm:entry-point')
Future<void> quickEntryBackgroundHandler(NotificationResponse response) async {
  DartPluginRegistrant.ensureInitialized();
  await QuickEntryService.handleResponse(response);
}

/// Catat transaksi langsung dari notifikasi tanpa membuka app.
///
/// Notifikasi permanen punya dua tombol ("Pengeluaran" dan "Pemasukan") dengan
/// kolom ketik. Tulis mis. `makan siang 25rb`, lalu kirim: transaksi langsung
/// tersimpan ke Firestore lewat isolate latar belakang.
class QuickEntryService {
  QuickEntryService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _mainId = 2000;
  static const _resultId = 2001;
  static const _expenseAction = 'qe_expense';
  static const _incomeAction = 'qe_income';

  static bool _ready = false;

  static const _settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );

  /// Mendaftarkan penangan tombol notifikasi. Panggil setelah
  /// `NotificationService.init()`.
  static Future<void> init() async {
    await _plugin.initialize(
      _settings,
      onDidReceiveNotificationResponse: (r) => handleResponse(r),
      onDidReceiveBackgroundNotificationResponse: quickEntryBackgroundHandler,
    );
    _ready = true;
  }

  static const _mainDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'quick_entry_channel',
      'Catat Cepat',
      channelDescription: 'Tambah transaksi langsung dari notifikasi',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: false,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          _expenseAction,
          'Pengeluaran',
          showsUserInterface: false,
          cancelNotification: false,
          inputs: <AndroidNotificationActionInput>[
            AndroidNotificationActionInput(label: 'mis. makan siang 25rb'),
          ],
        ),
        AndroidNotificationAction(
          _incomeAction,
          'Pemasukan',
          showsUserInterface: false,
          cancelNotification: false,
          inputs: <AndroidNotificationActionInput>[
            AndroidNotificationActionInput(label: 'mis. gaji 5jt'),
          ],
        ),
      ],
    ),
  );

  static const _title = 'DafMoney · Catat cepat';
  static const _body = 'Ketuk Pengeluaran / Pemasukan, lalu ketik mis. "kopi 15rb".';

  /// Menampilkan notifikasi catat cepat dan menjadwalkan pemasangan ulang
  /// tiap pagi (supaya muncul lagi setelah HP restart).
  static Future<void> show() async {
    await _plugin.show(_mainId, _title, _body, _mainDetails);
    try {
      tz.initializeTimeZones();
      final now = DateTime.now();
      var at = DateTime(now.year, now.month, now.day, 6);
      if (at.isBefore(now)) at = at.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        _mainId,
        _title,
        _body,
        tz.TZDateTime.from(at, tz.local),
        _mainDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }

  static Future<void> hide() => _plugin.cancel(_mainId);

  static Future<void> _flash(String title, String body) {
    return _plugin.show(
      _resultId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'quick_entry_result_channel',
          'Hasil Catat Cepat',
          channelDescription: 'Konfirmasi transaksi yang dicatat dari notifikasi',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          timeoutAfter: 5000,
        ),
      ),
    );
  }

  static Future<void> _ensureReady() async {
    if (_ready) return;
    await _plugin.initialize(_settings);
    _ready = true;
  }

  /// Notifikasi hasil singkat (dipakai juga oleh tombol template widget).
  static Future<void> notify(String title, String body) async {
    await _ensureReady();
    await _flash(title, body);
  }

  static Future<void> handleResponse(NotificationResponse r) async {
    final action = r.actionId;
    if (action != _expenseAction && action != _incomeAction) return;
    final type = action == _incomeAction ? EntryType.income : EntryType.expense;

    await _ensureReady();
    final result = await QuickEntrySaver.save(type, r.input ?? '');
    await _flash(result.title, result.body);
    // Kembalikan notifikasi utama (menghentikan animasi "mengirim").
    await show();
  }
}
