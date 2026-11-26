import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/error/app_exception.dart';
import '../../transactions/data/transaction_repository.dart' show writeSafe;
import '../domain/user_profile.dart';

const accountDataCollections = <String>[
  'transactions',
  'receipts',
  'wallets',
  'budgets',
  'categories',
  'recurring',
  'transfers',
  'goals',
  'debts',
];

class SettingsRepository {
  SettingsRepository(this._db);

  final FirebaseFirestore _db;

  static const _deleteTimeout = Duration(seconds: 30);

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  Stream<UserProfile> watchProfile(String uid) {
    return _user(uid).snapshots().map((s) {
      final m = s.data() ?? const <String, dynamic>{};
      return UserProfile(
        name: (m['name'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        initialBalance: (m['initialBalance'] as num?)?.toInt() ?? 0,
      );
    });
  }

  Future<void> updateName(String uid, String name) =>
      writeSafe(() => _user(uid).update({'name': name}));

  Future<void> setInitialBalance(String uid, int value) =>
      writeSafe(() => _user(uid).update({'initialBalance': value}));

  Future<void> _confirmed(Future<void> Function() op) async {
    try {
      await op().timeout(_deleteTimeout);
    } on TimeoutException {
      throw const AppException(
        'Koneksi lambat atau terputus, penghapusan belum selesai. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  Future<void> _deleteCollection(String uid, String name) async {
    final col = _user(uid).collection(name);
    String? lastFirstId;
    while (true) {
      final snap = await col.limit(400).get();
      if (snap.docs.isEmpty) break;
      if (snap.docs.first.id == lastFirstId) {
        throw const AppException(
          'Gagal menghapus data. Periksa koneksi lalu coba lagi.',
        );
      }
      lastFirstId = snap.docs.first.id;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await _confirmed(() => batch.commit());
    }
  }

  Future<void> deleteAllTransactions(String uid) async {
    await _deleteCollection(uid, 'transactions');
    await _deleteCollection(uid, 'receipts');
  }

  Future<void> deleteAllData(String uid) async {
    for (final name in accountDataCollections) {
      await _deleteCollection(uid, name);
    }
    await _confirmed(() => _user(uid).delete());
  }
}
