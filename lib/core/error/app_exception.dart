import 'package:firebase_core/firebase_core.dart' show FirebaseException;

class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

String firebaseMessage(String code) {
  switch (code) {
    case 'permission-denied':
      return 'Akses ditolak. Pastikan email terverifikasi dan aturan Firestore sudah di-deploy.';
    case 'unavailable':
    case 'network-request-failed':
      return 'Tidak ada koneksi internet.';
    case 'not-found':
      return 'Data tidak ditemukan.';
    case 'failed-precondition':
      return 'Query membutuhkan index Firestore. Lihat log untuk tautan pembuatannya.';
    default:
      return 'Terjadi kesalahan ($code). Coba lagi.';
  }
}

String errorText(Object error) {
  if (error is AppException) return error.message;
  if (error is FirebaseException) return firebaseMessage(error.code);
  return 'Terjadi kesalahan. Coba lagi.';
}

Future<String?> runGuarded(Future<void> Function() action) async {
  try {
    await action();
    return null;
  } catch (e) {
    return errorText(e);
  }
}
