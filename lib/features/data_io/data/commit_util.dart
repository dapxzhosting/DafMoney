import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/error/app_exception.dart';

/// Commit batch dengan batas waktu. Saat offline, Future Firestore baru selesai
/// setelah server menjawab, sehingga impor/restore besar bisa menggantung.
Future<void> commitBatch(
  WriteBatch batch, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  try {
    await batch.commit().timeout(timeout);
  } on TimeoutException {
    throw const AppException(
      'Koneksi lambat atau offline. Sebagian data tersimpan di perangkat dan '
      'akan dikirim saat online. Coba lagi setelah online; data yang sudah '
      'masuk akan dilewati.',
    );
  }
}
