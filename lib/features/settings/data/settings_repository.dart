import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/user_profile.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  final FirebaseFirestore _db;

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
      _user(uid).update({'name': name});

  Future<void> setInitialBalance(String uid, int value) =>
      _user(uid).update({'initialBalance': value});

  Future<void> _deleteCollection(String uid, String name) async {
    final col = _user(uid).collection(name);
    while (true) {
      final snap = await col.limit(400).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  Future<void> deleteAllTransactions(String uid) =>
      _deleteCollection(uid, 'transactions');

  Future<void> deleteAllData(String uid) async {
    for (final name in const ['transactions', 'budgets', 'categories']) {
      await _deleteCollection(uid, name);
    }
    await _user(uid).delete();
  }
}
