import '../../../core/error/app_exception.dart';

/// Error yang sudah diterjemahkan ke pesan yang ramah untuk pengguna.
class AuthFailure implements AppException {
  const AuthFailure(this.message);

  @override
  final String message;

  factory AuthFailure.fromCode(String code) {
    switch (code) {
      case 'invalid-email':
        return const AuthFailure('Format email tidak valid.');
      case 'user-disabled':
        return const AuthFailure('Akun ini telah dinonaktifkan.');
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return const AuthFailure('Email atau kata sandi salah.');
      case 'email-already-in-use':
        return const AuthFailure('Email sudah terdaftar. Silakan masuk.');
      case 'weak-password':
        return const AuthFailure('Kata sandi terlalu lemah.');
      case 'too-many-requests':
        return const AuthFailure(
            'Terlalu banyak percobaan. Coba lagi beberapa menit lagi.');
      case 'network-request-failed':
        return const AuthFailure('Tidak ada koneksi internet.');
      case 'operation-not-allowed':
        return const AuthFailure(
            'Login Email/Password belum diaktifkan di Firebase Console.');
      case 'requires-recent-login':
        return const AuthFailure(
            'Demi keamanan, keluar lalu masuk lagi, kemudian ulangi.');
      case 'permission-denied':
        return const AuthFailure('Akses ditolak oleh aturan keamanan.');
      default:
        return AuthFailure('Terjadi kesalahan ($code). Coba lagi.');
    }
  }

  @override
  String toString() => message;
}
