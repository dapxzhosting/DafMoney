import 'dart:ui' show DartPluginRegistrant;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/transactions/data/transaction_repository.dart';
import '../../firebase_options.dart';
import '../models/entry_type.dart';
import 'quick_entry_parser.dart';

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

  static String _rupiah(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp $buf';
  }

  static Future<String?> _currentUid() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    final auth = FirebaseAuth.instance;
    final user =
        auth.currentUser ??
        await auth
            .authStateChanges()
            .first
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
    return user?.uid;
  }

  static Future<void> handleResponse(NotificationResponse r) async {
    final action = r.actionId;
    if (action != _expenseAction && action != _incomeAction) return;
    final type = action == _incomeAction ? EntryType.income : EntryType.expense;

    if (!_ready) {
      await _plugin.initialize(_settings);
      _ready = true;
    }

    final parsed = parseQuickEntry(r.input ?? '');
    if (parsed == null) {
      await _flash('Nominal tidak terbaca', 'Tulis dengan nominal, mis. "makan 25rb".');
      await show();
      return;
    }

    try {
      final uid = await _currentUid();
      if (uid == null) {
        await _flash('Belum masuk', 'Buka DafMoney dan login dulu.');
        await show();
        return;
      }

      final db = FirebaseFirestore.instance;
      final user = db.collection('users').doc(uid);

      final cats = await user.collection('categories').get();
      final ofType = cats.docs
          .where((d) => EntryType.parse(d.data()['type'] as String?) == type)
          .toList();
      String? pick(bool Function(String name) test) {
        for (final d in ofType) {
          if (test(((d.data()['name'] as String?) ?? '').toLowerCase())) {
            return d.id;
          }
        }
        return null;
      }

      final guess = guessCategoryName(parsed.note, type);
      final categoryId =
          (guess == null ? null : pick((n) => n == guess)) ??
          pick((n) => n == 'lainnya') ??
          (ofType.isNotEmpty ? ofType.first.id : '');

      // Dompet: pakai dompet pertama (tertua) bila ada.
      String? walletId;
      final wallets = await user.collection('wallets').get();
      if (wallets.docs.isNotEmpty) {
        final docs = wallets.docs.toList()
          ..sort((a, b) {
            DateTime t(QueryDocumentSnapshot<Map<String, dynamic>> d) {
              final v = d.data()['createdAt'];
              return v is Timestamp ? v.toDate() : DateTime.now();
            }

            return t(a).compareTo(t(b));
          });
        walletId = docs.first.id;
      }

      await TransactionRepository(db).add(
        uid,
        type: type,
        amount: parsed.amount,
        categoryId: categoryId,
        note: parsed.note,
        date: DateTime.now(),
        walletId: walletId,
      );

      final sign = type == EntryType.income ? '+' : '-';
      await _flash('Tersimpan ✓', '${parsed.note} · $sign${_rupiah(parsed.amount)}');
    } catch (e) {
      await _flash('Gagal menyimpan', 'Coba lagi atau buka DafMoney. ($e)');
    }
    // Kembalikan notifikasi utama (menghentikan animasi "mengirim").
    await show();
  }
}
