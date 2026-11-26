import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/entry_type.dart';
import '../../../core/utils/date_utils.dart';
import '../../transactions/data/transaction_repository.dart' show writeSafe;
import '../../../core/services/error_reporter.dart';
import '../domain/recurring_entry.dart';

class RecurringRepository {
  RecurringRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _user(uid).collection('recurring');

  DateTime _date(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();

  RecurringEntry _fromMap(String id, Map<String, dynamic> m) {
    final w = m['walletId'];
    return RecurringEntry(
      id: id,
      type: EntryType.parse(m['type'] as String?),
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      categoryId: (m['categoryId'] as String?) ?? '',
      note: (m['note'] as String?) ?? '',
      walletId: (w is String && w.isNotEmpty) ? w : null,
      frequency: Frequency.parse(m['frequency'] as String?),
      startDate: _date(m['startDate']),
      nextDate: _date(m['nextDate']),
      anchorDay: (m['anchorDay'] as num?)?.toInt() ?? 1,
      active: m['active'] != false,
    );
  }

  Stream<List<RecurringEntry>> watch(String uid) {
    return _col(uid).snapshots().map((snap) {
      final list = snap.docs.map((d) => _fromMap(d.id, d.data())).toList();
      list.sort((a, b) => a.nextDate.compareTo(b.nextDate));
      return list;
    });
  }

  Future<void> add(
    String uid, {
    required EntryType type,
    required int amount,
    required String categoryId,
    required String note,
    required Frequency frequency,
    required DateTime startDate,
    String? walletId,
  }) {
    final start = dateOnly(startDate);
    return writeSafe(
      () => _col(uid).add({
        'type': type.name,
        'amount': amount,
        'categoryId': categoryId,
        'note': note,
        if (walletId != null) 'walletId': walletId,
        'frequency': frequency.name,
        'startDate': Timestamp.fromDate(start),
        'nextDate': Timestamp.fromDate(start),
        'anchorDay': start.day,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  Future<void> update(
    String uid,
    RecurringEntry old, {
    required EntryType type,
    required int amount,
    required String categoryId,
    required String note,
    required Frequency frequency,
    required DateTime startDate,
    String? walletId,
  }) {
    final start = dateOnly(startDate);
    final newNext = nextDateAfterEdit(
      start: start,
      oldStart: old.startDate,
      oldNext: old.nextDate,
      oldFrequency: old.frequency,
      frequency: frequency,
      today: dateOnly(DateTime.now()),
    );
    return writeSafe(
      () => _col(uid).doc(old.id).update({
        'type': type.name,
        'amount': amount,
        'categoryId': categoryId,
        'note': note,
        'walletId': walletId ?? FieldValue.delete(),
        'frequency': frequency.name,
        'startDate': Timestamp.fromDate(start),
        'anchorDay': start.day,
        if (newNext != null) 'nextDate': Timestamp.fromDate(newNext),
      }),
    );
  }

  Future<void> setActive(String uid, String id, bool active) async {
    // Saat diaktifkan kembali, lewati tanggal yang terlewat selama dijeda
    // supaya tidak muncul transaksi susulan sekaligus.
    DateTime? newNext;
    if (active) {
      try {
        final snap = await _col(uid).doc(id).get();
        final data = snap.data();
        if (snap.exists && data != null) {
          final r = _fromMap(snap.id, data);
          final today = dateOnly(DateTime.now());
          if (r.nextDate.isBefore(today)) {
            newNext = firstOccurrenceOnOrAfter(
              start: r.nextDate,
              today: today,
              frequency: r.frequency,
              anchorDay: r.anchorDay,
            );
          }
        }
      } catch (_) {}
    }
    return writeSafe(
      () => _col(uid).doc(id).update({
        'active': active,
        if (newNext != null) 'nextDate': Timestamp.fromDate(newNext),
      }),
    );
  }

  Future<void> delete(String uid, String id) =>
      writeSafe(() => _col(uid).doc(id).delete());

  Future<int> processDue(String uid) async {
    final today = dateOnly(DateTime.now());
    final snap = await _col(uid)
        .where('nextDate', isLessThanOrEqualTo: Timestamp.fromDate(today))
        .get();
    var created = 0;
    for (final doc in snap.docs) {
      if (doc.data()['active'] == false) continue;
      try {
        created += await _db.runTransaction<int>((tx) async {
          final fresh = await tx.get(doc.reference);
          final data = fresh.data();
          if (!fresh.exists || data == null || data['active'] == false) {
            return 0;
          }
          final r = _fromMap(fresh.id, data);
          final dates = dueDates(
            next: r.nextDate,
            today: today,
            frequency: r.frequency,
            anchorDay: r.anchorDay,
          );
          if (dates.isEmpty) return 0;
          final txCol = _user(uid).collection('transactions');
          for (final d in dates) {
            tx.set(txCol.doc(), {
              'type': r.type.name,
              'amount': r.amount,
              'categoryId': r.categoryId,
              'note': r.note,
              'date': Timestamp.fromDate(d),
              'createdAt': FieldValue.serverTimestamp(),
              if (r.walletId != null) 'walletId': r.walletId,
              'recurringId': r.id,
            });
          }
          final next = nextOccurrence(dates.last, r.frequency, r.anchorDay);
          tx.update(doc.reference, {'nextDate': Timestamp.fromDate(next)});
          return dates.length;
        });
      } catch (e, st) {
        reportError(e, st);
      }
    }
    return created;
  }
}
