import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/date_utils.dart';
import '../../transactions/data/transaction_repository.dart' show writeSafe;
import '../domain/wallet_transfer.dart';

class TransferRepository {
  TransferRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('transfers');

  Stream<List<WalletTransfer>> watch(String uid) {
    return _col(uid).snapshots().map((snap) {
      final list = snap.docs.map((d) {
        final m = d.data();
        final date = m['date'];
        return WalletTransfer(
          id: d.id,
          fromWalletId: (m['fromWalletId'] as String?) ?? '',
          toWalletId: (m['toWalletId'] as String?) ?? '',
          amount: (m['amount'] as num?)?.toInt() ?? 0,
          note: (m['note'] as String?) ?? '',
          date: date is Timestamp ? date.toDate() : DateTime.now(),
        );
      }).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  Future<void> add(
    String uid, {
    required String fromWalletId,
    required String toWalletId,
    required int amount,
    required String note,
    required DateTime date,
  }) {
    return writeSafe(
      () => _col(uid).add({
        'fromWalletId': fromWalletId,
        'toWalletId': toWalletId,
        'amount': amount,
        'note': note,
        'date': Timestamp.fromDate(dateOnly(date)),
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  Future<void> delete(String uid, String id) =>
      writeSafe(() => _col(uid).doc(id).delete());

  /// Apakah ada transfer yang memakai dompet ini (asal atau tujuan).
  Future<bool> usesWallet(String uid, String walletId) async {
    final from = await _col(
      uid,
    ).where('fromWalletId', isEqualTo: walletId).limit(1).get();
    if (from.docs.isNotEmpty) return true;
    final to = await _col(
      uid,
    ).where('toWalletId', isEqualTo: walletId).limit(1).get();
    return to.docs.isNotEmpty;
  }
}
