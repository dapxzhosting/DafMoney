import 'package:flutter/services.dart';

class ScreenSecurityService {
  ScreenSecurityService._();

  static const _channel = MethodChannel('dafmoney/secure_screen');

  static Future<void> setSecure(bool secure) async {
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } catch (_) {}
  }
}
