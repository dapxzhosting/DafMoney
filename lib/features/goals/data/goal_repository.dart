import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/date_utils.dart';
import '../../transactions/data/transaction_repository.dart' show writeSafe;
import '../domain/savings_goal.dart';

class GoalRepository {
  GoalRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('goals');

  Stream<List<SavingsGoal>> watch(String uid) {
    return _col(uid).snapshots().map((snap) {
      final list = snap.docs.map((d) {
        final m = d.data();
        final dl = m['deadline'];
        return SavingsGoal(
          id: d.id,
          name: (m['name'] as String?) ?? '',
          iconKey: (m['icon'] as String?) ?? 'savings',
          colorValue: (m['color'] as num?)?.toInt() ?? 0xFF14B8A6,
          target: (m['target'] as num?)?.toInt() ?? 0,
          saved: (m['saved'] as num?)?.toInt() ?? 0,
          deadline: dl is Timestamp ? dl.toDate() : null,
        );
      }).toList();
      list.sort((a, b) {
        if (a.reached != b.reached) return a.reached ? 1 : -1;
        final da = a.deadline, db = b.deadline;
        if (da != null && db != null) return da.compareTo(db);
        if (da != null) return -1;
        if (db != null) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return list;
    });
  }

  Future<void> add(
    String uid, {
    required String name,
    required String iconKey,
    required int colorValue,
    required int target,
    required int saved,
    DateTime? deadline,
  }) {
    return writeSafe(
      () => _col(uid).add({
        'name': name,
        'icon': iconKey,
        'color': colorValue,
        'target': target,
        'saved': saved,
        if (deadline != null)
          'deadline': Timestamp.fromDate(dateOnly(deadline)),
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  Future<void> update(
    String uid,
    String id, {
    required String name,
    required String iconKey,
    required int colorValue,
    required int target,
    DateTime? deadline,
  }) {
    return writeSafe(
      () => _col(uid).doc(id).update({
        'name': name,
        'icon': iconKey,
        'color': colorValue,
        'target': target,
        'deadline': deadline == null
            ? FieldValue.delete()
            : Timestamp.fromDate(dateOnly(deadline)),
      }),
    );
  }

  Future<void> adjustSaved(String uid, String id, int delta) async {
    final ref = _col(uid).doc(id);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final cur = (snap.data()?['saved'] as num?)?.toInt() ?? 0;
        final next = cur + delta;
        if (next < 0) {
          throw const AppException('Dana yang ditarik melebihi isi tabungan.');
        }
        tx.update(ref, {'saved': next});
      });
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        throw const AppException(
          'Butuh koneksi internet untuk mengubah dana tabungan.',
        );
      }
      rethrow;
    }
  }

  Future<void> delete(String uid, String id) =>
      writeSafe(() => _col(uid).doc(id).delete());
}
