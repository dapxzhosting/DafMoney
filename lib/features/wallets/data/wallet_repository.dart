import 'package:cloud_firestore/cloud_firestore.dart';

import '../../transactions/data/transaction_repository.dart' show writeSafe;
import '../domain/wallet.dart';

class WalletRepository {
  WalletRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _user(uid).collection('wallets');

  Wallet _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return Wallet(
      id: d.id,
      name: (m['name'] as String?) ?? '',
      iconKey: (m['icon'] as String?) ?? 'payments',
      colorValue: (m['color'] as num?)?.toInt() ?? 0xFF14B8A6,
      initialBalance: (m['initialBalance'] as num?)?.toInt() ?? 0,
    );
  }

  DateTime _created(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final v = d.data()['createdAt'];
    // createdAt masih null sesaat setelah dibuat (menunggu server): anggap terbaru.
    return v is Timestamp ? v.toDate() : DateTime.now();
  }

  Stream<List<Wallet>> watch(String uid) {
    return _col(uid).snapshots().map((snap) {
      final docs = snap.docs.toList()
        ..sort((a, b) => _created(a).compareTo(_created(b)));
      return docs.map(_fromDoc).toList();
    });
  }

  Future<void> add(
    String uid, {
    required String name,
    required String iconKey,
    required int colorValue,
    required int initialBalance,
  }) {
    return writeSafe(() => _col(uid).add({
          'name': name,
          'icon': iconKey,
          'color': colorValue,
          'initialBalance': initialBalance,
          'createdAt': FieldValue.serverTimestamp(),
        }));
  }

  Future<void> update(
    String uid,
    String id, {
    required String name,
    required String iconKey,
    required int colorValue,
    required int initialBalance,
  }) {
    return writeSafe(() => _col(uid).doc(id).update({
          'name': name,
          'icon': iconKey,
          'color': colorValue,
          'initialBalance': initialBalance,
        }));
  }

  /// Menghapus dompet. Transaksi yang memakai dompet ini tidak dihapus,
  /// hanya dilepas dari dompetnya (menjadi "tanpa dompet").
  Future<void> delete(String uid, String id) async {
    final txCol = _user(uid).collection('transactions');
    while (true) {
      final snap =
          await txCol.where('walletId', isEqualTo: id).limit(400).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.update(d.reference, {'walletId': FieldValue.delete()});
      }
      await batch.commit();
    }
    await _col(uid).doc(id).delete();
  }
}
