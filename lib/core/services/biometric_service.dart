import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum AuthResult { success, failed, unavailable }

class BiometricService {
  BiometricService._();

  static final LocalAuthentication _auth = LocalAuthentication();

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
