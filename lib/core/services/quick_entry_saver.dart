import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/transactions/data/transaction_repository.dart';
import '../../firebase_options.dart';
import '../constants/app_constants.dart';
import '../error/app_exception.dart';
import '../models/entry_type.dart';
import 'quick_entry_parser.dart';

class QuickSaveResult {
  const QuickSaveResult({
    required this.ok,
    required this.title,
    required this.body,
  });

  final bool ok;
  final String title;
  final String body;
}

class QuickNote {
  const QuickNote({
    required this.note,
    required this.amount,
    required this.count,
  });

  final String note;
  final int amount;
  final int count;

  String get label => '$note · ${shortRupiah(amount)}';
}

String shortRupiah(int v) {
  if (v >= 1000000) {
    final j = v / 1000000;
    return '${j == j.roundToDouble() ? j.round() : j.toStringAsFixed(1)}jt';
  }
  if (v >= 1000) {
    final k = v / 1000;
    return '${k == k.roundToDouble() ? k.round() : k.toStringAsFixed(1)}rb';
  }
  return '$v';
}

String _rupiah(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return 'Rp $buf';
}

String _norm(String s) =>
    s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

class QuickEntrySaver {
  QuickEntrySaver._();

  static Future<void> ensureFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate-app')) rethrow;
    }
  }

  static Future<String?> currentUid() async {
    await ensureFirebase();
    final auth = FirebaseAuth.instance;
    final user =
        auth.currentUser ??
        await auth.authStateChanges().first.timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );
    return user?.uid;
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> _cacheFirst(
    CollectionReference<Map<String, dynamic>> col,
  ) async {
    try {
      final cached = await col.get(const GetOptions(source: Source.cache));
      if (cached.docs.isNotEmpty) return cached;
    } catch (_) {}
    return col.get();
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> _recent(
    DocumentReference<Map<String, dynamic>> user,
  ) {
    return user
        .collection('transactions')
        .orderBy('date', descending: true)
        .limit(250)
        .get();
  }

  static Future<bool> _appLockOn(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return prefs.getBool('${AppConstants.appLockKey}_$uid') ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<List<QuickNote>> topNotes(
    EntryType type, {
    int limit = 6,
  }) async {
    final uid = await currentUid();
    if (uid == null) return const [];
    // Catat cepat berjalan tanpa layar kunci. Saat kunci aplikasi aktif,
    // jangan tampilkan catatan/nominal dari riwayat transaksi.
    if (await _appLockOn(uid)) return const [];
    final user = FirebaseFirestore.instance.collection('users').doc(uid);
    final past = await _recent(user);

    final counts = <String, int>{};
    final latest = <String, QuickNote>{};
    final order = <String>[];
    for (final d in past.docs) {
      final m = d.data();
      if (EntryType.parse(m['type'] as String?) != type) continue;
      final note = ((m['note'] as String?) ?? '').trim();
      final amount = (m['amount'] as num?)?.toInt() ?? 0;
      if (note.isEmpty || amount <= 0) continue;
      final key = _norm(note);
      if (!counts.containsKey(key)) {
        order.add(key);
        latest[key] = QuickNote(note: note, amount: amount, count: 0);
      }
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final keys = order.toList()
      ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
    return [
      for (final k in keys.take(limit))
        QuickNote(
          note: latest[k]!.note,
          amount: latest[k]!.amount,
          count: counts[k] ?? 0,
        ),
    ];
  }

  static Future<QuickSaveResult> save(EntryType type, String raw) async {
    final text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) {
      return const QuickSaveResult(
        ok: false,
        title: 'Kosong',
        body: 'Tulis catatan, mis. "makan 25rb" atau "Magnum 1".',
      );
    }
    try {
      final uid = await currentUid();
      if (uid == null) {
        return const QuickSaveResult(
          ok: false,
          title: 'Belum masuk',
          body: 'Buka DafMoney dan login dulu.',
        );
      }

      final db = FirebaseFirestore.instance;
      final user = db.collection('users').doc(uid);
      final past = await _recent(user);

      Map<String, dynamic>? lookup(String note) {
        final key = _norm(note);
        for (final d in past.docs) {
          final m = d.data();
          if (EntryType.parse(m['type'] as String?) != type) continue;
          if (_norm((m['note'] as String?) ?? '') == key) return m;
        }
        return null;
      }

      var hist = lookup(text);
      String note;
      int? amount;
      if (hist != null) {
        note = ((hist['note'] as String?) ?? text).trim();
        amount = (hist['amount'] as num?)?.toInt();
      } else {
        final parsed = parseQuickEntry(text);
        if (parsed != null) {
          note = parsed.note;
          amount = parsed.amount;
          hist = lookup(note);
        } else {
          note = text;
          amount = null;
        }
      }
      if (amount == null || amount <= 0) {
        return QuickSaveResult(
          ok: false,
          title: 'Nominal tidak terbaca',
          body:
              '"$text" belum pernah dicatat. Tulis dengan nominal, mis. "$text 8rb".',
        );
      }

      final cats = await _cacheFirst(user.collection('categories'));
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

      final histCat = hist?['categoryId'] as String?;
      final guess = guessCategoryName(note, type);
      final categoryId =
          (histCat != null && ofType.any((d) => d.id == histCat)
              ? histCat
              : null) ??
          (guess == null ? null : pick((n) => n == guess)) ??
          pick((n) => n == 'lainnya') ??
          (ofType.isNotEmpty ? ofType.first.id : '');

      if (categoryId.isEmpty) {
        return const QuickSaveResult(
          ok: false,
          title: 'Kategori belum ada',
          body: 'Buka DafMoney dan buat kategori dulu.',
        );
      }
      if (note.length > 200) note = note.substring(0, 200);

      String? walletId;
      final wallets = await _cacheFirst(user.collection('wallets'));
      if (wallets.docs.isNotEmpty) {
        DateTime created(QueryDocumentSnapshot<Map<String, dynamic>> d) {
          final v = d.data()['createdAt'];
          return v is Timestamp ? v.toDate() : DateTime.now();
        }

        final docs = wallets.docs.toList()
          ..sort((a, b) => created(a).compareTo(created(b)));
        walletId = docs.first.id;
        final histWallet = hist?['walletId'];
        if (histWallet is String && docs.any((d) => d.id == histWallet)) {
          walletId = histWallet;
        }
      }

      await TransactionRepository(db).add(
        uid,
        type: type,
        amount: amount,
        categoryId: categoryId,
        note: note,
        date: DateTime.now(),
        walletId: walletId,
      );

      final sign = type == EntryType.income ? '+' : '-';
      return QuickSaveResult(
        ok: true,
        title: 'Tersimpan ✓',
        body: '$note · $sign${_rupiah(amount)}',
      );
    } catch (e) {
      return QuickSaveResult(
        ok: false,
        title: 'Gagal menyimpan',
        body: 'Coba lagi atau buka DafMoney. (${errorText(e)})',
      );
    }
  }
}
