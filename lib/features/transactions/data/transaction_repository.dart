import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/entry_type.dart';
import '../../../core/utils/civil_date.dart';
import '../../../core/services/error_reporter.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/money_transaction.dart';

Future<void> writeSafe(Future<void> Function() op) async {
  // Simpan jejak pemanggil: error dari server (mis. permission-denied) datang
  // belakangan dan stack aslinya hanya berisi kode plugin, jadi tanpa ini
  // Crashlytics tidak bisa menunjukkan penulisan mana yang ditolak.
  final caller = StackTrace.current;
  final future = op();
  unawaited(
    future.catchError((Object e, StackTrace _) {
      reportError(e, caller);
    }),
  );
  await Future.any<void>([
    future,
    Future<void>.delayed(const Duration(milliseconds: 800)),
  ]);
}

class TransactionRepository {
  TransactionRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('transactions');

  DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  DateTime _civil(dynamic v) {
    if (v is Timestamp) return civilDateFromTimestamp(v);
    final d = _parseDate(v);
    return DateTime(d.year, d.month, d.day);
  }

  MoneyTransaction _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    final w = m['walletId'];
    final r = m['recurringId'];
    return MoneyTransaction(
      id: d.id,
      type: EntryType.parse(m['type'] as String?),
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      categoryId: (m['categoryId'] as String?) ?? '',
      note: (m['note'] as String?) ?? '',
      date: _civil(m['date']),
      createdAt: _parseDate(m['createdAt']),
      walletId: (w is String && w.isNotEmpty) ? w : null,
      recurringId: (r is String && r.isNotEmpty) ? r : null,
      hasReceipt: m['hasReceipt'] == true,
    );
  }

  Stream<List<MoneyTransaction>> watchRange(String uid, DateRange range) {
    return _col(uid)
        .where('date', isGreaterThanOrEqualTo: civilLowerBound(range.start))
        .where('date', isLessThan: civilUpperBound(range.end))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map(_fromDoc)
              .where((t) => range.contains(t.date))
              .toList();
          list.sort((a, b) {
            final c = b.date.compareTo(a.date);
            return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
          });
          return list;
        });
  }

  Future<String> add(
    String uid, {
    required EntryType type,
    required int amount,
    required String categoryId,
    required String note,
    required DateTime date,
    String? walletId,
    String? recurringId,
    bool hasReceipt = false,
  }) async {
    final ref = _col(uid).doc();
    await writeSafe(
      () => ref.set({
        'type': type.name,
        'amount': amount,
        'categoryId': categoryId,
        'note': note,
        'date': civilTimestamp(date),
        'createdAt': FieldValue.serverTimestamp(),
        if (walletId != null) 'walletId': walletId,
        if (recurringId != null) 'recurringId': recurringId,
        if (hasReceipt) 'hasReceipt': true,
      }),
    );
    return ref.id;
  }

  Future<void> update(
    String uid,
    String id, {
    required EntryType type,
    required int amount,
    required String categoryId,
    required String note,
    required DateTime date,
    String? walletId,
    String? recurringId,
    bool hasReceipt = false,
  }) {
    return writeSafe(
      () => _col(uid).doc(id).update({
        'type': type.name,
        'amount': amount,
        'categoryId': categoryId,
        'note': note,
        'date': civilTimestamp(date),
        'walletId': walletId ?? FieldValue.delete(),
        'hasReceipt': hasReceipt ? true : FieldValue.delete(),
        if (recurringId != null) 'recurringId': recurringId,
      }),
    );
  }

  Future<void> restore(
    String uid,
    MoneyTransaction t, {
    required bool hasReceipt,
  }) {
    return writeSafe(
      () => _col(uid).doc(t.id).set({
        'type': t.type.name,
        'amount': t.amount,
        'categoryId': t.categoryId,
        'note': t.note,
        'date': civilTimestamp(t.date),
        'createdAt': FieldValue.serverTimestamp(),
        if (t.walletId != null) 'walletId': t.walletId,
        if (t.recurringId != null) 'recurringId': t.recurringId,
        if (hasReceipt) 'hasReceipt': true,
      }),
    );
  }

  Future<void> delete(String uid, String id) {
    final user = _db.collection('users').doc(uid);
    final batch = _db.batch()
      ..delete(_col(uid).doc(id))
      ..delete(user.collection('receipts').doc(id));
    return writeSafe(() => batch.commit());
  }

  Future<List<MoneyTransaction>> fetchAll(String uid) async {
    final snap = await _col(uid).get();
    return snap.docs.map(_fromDoc).toList();
  }

  Stream<Map<String, Balance>> watchTotalsByWallet(String uid) {
    return _col(uid).snapshots().map((snap) {
      final inc = <String, int>{};
      final exp = <String, int>{};
      for (final d in snap.docs) {
        final m = d.data();
        final w = m['walletId'];
        final key = (w is String && w.isNotEmpty) ? w : '';
        final amount = (m['amount'] as num?)?.toInt() ?? 0;
        if (m['type'] == 'income') {
          inc[key] = (inc[key] ?? 0) + amount;
        } else {
          exp[key] = (exp[key] ?? 0) + amount;
        }
      }
      final keys = {...inc.keys, ...exp.keys};
      return {
        for (final k in keys)
          k: Balance(income: inc[k] ?? 0, expense: exp[k] ?? 0),
      };
    });
  }
}
