import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/error/app_exception.dart';
import '../domain/budget.dart';

class BudgetRepository {
  BudgetRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('budgets');

  Budget _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return Budget(
      id: d.id,
      categoryId: (m['categoryId'] as String?) ?? '',
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      month: (m['month'] as String?) ?? '',
    );
  }

  String idFor(String month, String categoryId) => '${month}_$categoryId';

  Stream<List<Budget>> watchMonth(String uid, String month) {
    return _col(uid)
        .where('month', isEqualTo: month)
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }

  Future<void> upsert(
    String uid, {
    required String categoryId,
    required String month,
    required int amount,
  }) {
    return _col(uid).doc(idFor(month, categoryId)).set({
      'categoryId': categoryId,
      'amount': amount,
      'month': month,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String uid, String id) => _col(uid).doc(id).delete();

  Future<void> copyMonth(String uid,
      {required String from, required String to}) async {
    final src = await _col(uid).where('month', isEqualTo: from).get();
    if (src.docs.isEmpty) {
      throw const AppException('Tidak ada anggaran di bulan sebelumnya.');
    }
    final existing = await _col(uid).where('month', isEqualTo: to).get();
    final have = existing.docs
        .map((d) => (d.data()['categoryId'] as String?) ?? '')
        .toSet();
    final batch = _db.batch();
    var count = 0;
    for (final d in src.docs) {
      final m = d.data();
      final cid = (m['categoryId'] as String?) ?? '';
      if (cid.isEmpty || have.contains(cid)) continue;
      batch.set(_col(uid).doc(idFor(to, cid)), {
        'categoryId': cid,
        'amount': m['amount'],
        'month': to,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      count++;
    }
    if (count == 0) {
      throw const AppException('Semua anggaran sudah ada di bulan ini.');
    }
    await batch.commit();
  }
}
