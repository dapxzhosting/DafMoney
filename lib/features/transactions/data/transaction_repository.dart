import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/entry_type.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/money_transaction.dart';

class TransactionRepository {
  TransactionRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('transactions');

  MoneyTransaction _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return MoneyTransaction(
      id: d.id,
      type: EntryType.parse(m['type'] as String?),
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      categoryId: (m['categoryId'] as String?) ?? '',
      note: (m['note'] as String?) ?? '',
      date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Transaksi dalam rentang [start, end), terbaru lebih dulu.
  Stream<List<MoneyTransaction>> watchRange(String uid, DateRange range) {
    return _col(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('date', isLessThan: Timestamp.fromDate(range.end))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
      });
      return list;
    });
  }

  Future<void> add(
    String uid, {
    required EntryType type,
    required int amount,
    required String categoryId,
    required String note,
    required DateTime date,
  }) {
    return _col(uid).add({
      'type': type.name,
      'amount': amount,
      'categoryId': categoryId,
      'note': note,
      'date': Timestamp.fromDate(dateOnly(date)),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(
    String uid,
    String id, {
    required EntryType type,
    required int amount,
    required String categoryId,
    required String note,
    required DateTime date,
  }) {
    return _col(uid).doc(id).update({
      'type': type.name,
      'amount': amount,
      'categoryId': categoryId,
      'note': note,
      'date': Timestamp.fromDate(dateOnly(date)),
    });
  }

  Future<void> delete(String uid, String id) => _col(uid).doc(id).delete();

  Future<List<MoneyTransaction>> fetchAll(String uid) async {
    final snap = await _col(uid).get();
    return snap.docs.map(_fromDoc).toList();
  }

  /// Total pemasukan & pengeluaran sepanjang waktu, diperbarui realtime.
  /// Dihitung di klien agar tidak membutuhkan index Firestore.
  Stream<Balance> watchTotals(String uid) {
    return _col(uid).snapshots().map((snap) {
      var inc = 0;
      var exp = 0;
      for (final d in snap.docs) {
        final m = d.data();
        final amount = (m['amount'] as num?)?.toInt() ?? 0;
        if (m['type'] == 'income') {
          inc += amount;
        } else {
          exp += amount;
        }
      }
      return Balance(income: inc, expense: exp);
    });
  }
}
