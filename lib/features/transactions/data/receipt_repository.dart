import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/error/app_exception.dart';
import 'transaction_repository.dart' show writeSafe;

/// Foto struk disimpan langsung di Firestore (tanpa Firebase Storage, jadi
/// tetap jalan di paket gratis). Satu dokumen per transaksi, id-nya sama
/// dengan id transaksi: users/{uid}/receipts/{transactionId}.
class ReceiptRepository {
  ReceiptRepository(this._db);

  /// Batas dokumen Firestore 1 MiB, sisakan ruang untuk field lain.
  static const int maxBytes = 900000;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('receipts');

  static void ensureSize(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      throw const AppException(
          'Foto struk terlalu besar. Coba ambil ulang dengan resolusi lebih kecil.');
    }
  }

  Future<void> save(String uid, String transactionId, Uint8List bytes) {
    ensureSize(bytes);
    return writeSafe(() => _col(uid).doc(transactionId).set({
          'data': Blob(bytes),
          'updatedAt': FieldValue.serverTimestamp(),
        }));
  }

  Future<Uint8List?> fetch(String uid, String transactionId) async {
    final doc = await _col(uid).doc(transactionId).get();
    final data = doc.data()?['data'];
    return data is Blob ? data.bytes : null;
  }

  Future<void> delete(String uid, String transactionId) =>
      writeSafe(() => _col(uid).doc(transactionId).delete());
}
