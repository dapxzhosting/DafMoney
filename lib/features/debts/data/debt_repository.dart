import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/date_utils.dart';
import '../../transactions/data/transaction_repository.dart' show writeSafe;
import '../domain/debt.dart';

class DebtRepository {
  DebtRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('debts');

  DateTime _date(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();

  Stream<List<Debt>> watch(String uid) {
    return _col(uid).snapshots().map((snap) {
      final list = snap.docs.map((d) {
        final m = d.data();
        final due = m['dueDate'];
        return Debt(
          id: d.id,
          person: (m['person'] as String?) ?? '',
          kind: DebtKind.parse(m['kind'] as String?),
          amount: (m['amount'] as num?)?.toInt() ?? 0,
          paid: (m['paid'] as num?)?.toInt() ?? 0,
          note: (m['note'] as String?) ?? '',
          date: _date(m['date']),
          dueDate: due is Timestamp ? due.toDate() : null,
        );
      }).toList();
      list.sort((a, b) {
        if (a.settled != b.settled) return a.settled ? 1 : -1;
        final da = a.dueDate, db = b.dueDate;
        if (da != null && db != null) return da.compareTo(db);
        if (da != null) return -1;
        if (db != null) return 1;
        return b.date.compareTo(a.date);
      });
      return list;
    });
  }

  Future<String> add(
    String uid, {
    required String person,
    required DebtKind kind,
    required int amount,
    required String note,
    required DateTime date,
    DateTime? dueDate,
  }) async {
    final ref = _col(uid).doc();
    await writeSafe(
      () => ref.set({
        'person': person,
        'kind': kind.name,
        'amount': amount,
        'paid': 0,
        'note': note,
        'date': Timestamp.fromDate(dateOnly(date)),
        if (dueDate != null) 'dueDate': Timestamp.fromDate(dateOnly(dueDate)),
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
    return ref.id;
  }

  Future<void> update(
    String uid,
    Debt old, {
    required String person,
    required DebtKind kind,
    required int amount,
    required String note,
    required DateTime date,
    DateTime? dueDate,
  }) {
    if (amount < old.paid) {
      throw const AppException(
        'Jumlah tidak boleh lebih kecil dari yang sudah dibayar.',
      );
    }
    return writeSafe(
      () => _col(uid).doc(old.id).update({
        'person': person,
        'kind': kind.name,
        'amount': amount,
        'note': note,
        'date': Timestamp.fromDate(dateOnly(date)),
        'dueDate': dueDate == null
            ? FieldValue.delete()
            : Timestamp.fromDate(dateOnly(dueDate)),
      }),
    );
  }

  Future<int> adjustPaid(String uid, String id, int delta) async {
    final ref = _col(uid).doc(id);
    try {
      return await _db.runTransaction<int>((tx) async {
        final snap = await tx.get(ref);
        final m = snap.data();
        if (m == null) throw const AppException('Catatan tidak ditemukan.');
        final amount = (m['amount'] as num?)?.toInt() ?? 0;
        final cur = (m['paid'] as num?)?.toInt() ?? 0;
        final next = cur + delta;
        if (next < 0 || next > amount) {
          throw const AppException('Jumlah pembayaran tidak valid.');
        }
        tx.update(ref, {'paid': next});
        return next;
      });
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        throw const AppException(
          'Butuh koneksi internet untuk mencatat pembayaran.',
        );
      }
      rethrow;
    }
  }

  Future<void> delete(String uid, String id) =>
      writeSafe(() => _col(uid).doc(id).delete());
}
