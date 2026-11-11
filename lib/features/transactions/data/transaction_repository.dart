import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/entry_type.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/money_transaction.dart';

Future<void> writeSafe(Future<void> Function() op) async {
  try {
    await op().timeout(const Duration(seconds: 6));
  } on TimeoutException {
    // Offline mode: Firestore will sync automatically when back online.
  }
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
      date: _parseDate(m['date']),
      createdAt: _parseDate(m['createdAt']),
      walletId: (w is String && w.isNotEmpty) ? w : null,
      recurringId: (r is String && r.isNotEmpty) ? r : null,
      hasReceipt: m['hasReceipt'] == true,
    );
  }

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

  /// Mengembalikan id dokumen baru (dipakai untuk menyimpan foto struk).
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
    await writeSafe(() => ref.set({
          'type': type.name,
          'amount': amount,
          'categoryId': categoryId,
          'note': note,
          'date': Timestamp.fromDate(dateOnly(date)),
          'createdAt': FieldValue.serverTimestamp(),
          if (walletId != null) 'walletId': walletId,
          if (recurringId != null) 'recurringId': recurringId,
          if (hasReceipt) 'hasReceipt': true,
        }));
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
    return writeSafe(() => _col(uid).doc(id).update({
          'type': type.name,
          'amount': amount,
          'categoryId': categoryId,
          'note': note,
          'date': Timestamp.fromDate(dateOnly(date)),
          'walletId': walletId ?? FieldValue.delete(),
          'hasReceipt': hasReceipt ? true : FieldValue.delete(),
          if (recurringId != null) 'recurringId': recurringId,
        }));
  }

  /// Menghapus transaksi beserta foto struknya (jika ada).
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

  /// Total per dompet. Kunci '' berarti transaksi tanpa dompet.
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
