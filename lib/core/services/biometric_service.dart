import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Hasil verifikasi identitas pengguna.
enum AuthResult {
  /// Sidik jari / wajah / PIN / pola perangkat berhasil diverifikasi.
  success,

  /// Dibatalkan atau salah. Aplikasi tetap terkunci.
  failed,

  /// Perangkat tidak punya kunci layar atau biometrik yang aktif.
  unavailable,
}

/// Pembungkus `local_auth`. Sengaja *fail-closed*: error apa pun TIDAK pernah
/// dianggap berhasil, supaya kunci aplikasi tidak bisa dilewati.
class BiometricService {
  BiometricService._();

  static final LocalAuthentication _auth = LocalAuthentication();

  /// Apakah perangkat punya biometrik atau kunci layar (PIN/pola/sandi).
  static Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<AuthResult> authenticate({
    String reason = 'Verifikasi identitas untuk membuka DafMoney',
  }) async {
    try {
      if (!await _auth.isDeviceSupported()) return AuthResult.unavailable;
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // false = boleh memakai PIN / pola / sandi perangkat sebagai cadangan.
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return ok ? AuthResult.success : AuthResult.failed;
    } on PlatformException catch (e) {
      const unavailable = {'NotAvailable', 'NotEnrolled', 'PasscodeNotSet'};
      return unavailable.contains(e.code)
          ? AuthResult.unavailable
          : AuthResult.failed;
    } catch (_) {
      return AuthResult.failed;
    }
  }
}
