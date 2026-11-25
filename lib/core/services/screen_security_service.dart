import 'package:flutter/services.dart';

/// Mengaktifkan FLAG_SECURE di Android: layar disembunyikan dari tangkapan
/// layar dan pratinjau app switcher. Dipakai saat kunci aplikasi aktif.
class ScreenSecurityService {
  ScreenSecurityService._();

  static const _channel = MethodChannel('dafmoney/secure_screen');

  static Future<void> setSecure(bool secure) async {
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } catch (_) {}
  }
}
