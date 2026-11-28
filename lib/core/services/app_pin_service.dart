import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PIN buatan aplikasi sendiri (4-6 digit). Disimpan hanya di perangkat
/// sebagai hash + salt per akun, tidak pernah dikirim ke Firestore.
class AppPinService {
  AppPinService._();

  static String _hashKey(String uid) => 'app_pin_hash_$uid';
  static String _saltKey(String uid) => 'app_pin_salt_$uid';

  static bool isValidFormat(String pin) => RegExp(r'^\d{4,6}$').hasMatch(pin);

  static bool has(SharedPreferences p, String uid) =>
      p.getString(_hashKey(uid)) != null;

  static String _hash(String pin, String salt) {
    List<int> d = utf8.encode('$salt:$pin');
    for (var i = 0; i < 5000; i++) {
      d = sha256.convert(d).bytes;
    }
    return base64Encode(d);
  }

  static Future<void> set(SharedPreferences p, String uid, String pin) async {
    final rnd = Random.secure();
    final salt = base64Encode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    await p.setString(_saltKey(uid), salt);
    await p.setString(_hashKey(uid), _hash(pin, salt));
  }

  static bool verify(SharedPreferences p, String uid, String pin) {
    final salt = p.getString(_saltKey(uid));
    final stored = p.getString(_hashKey(uid));
    if (salt == null || stored == null) return false;
    final candidate = _hash(pin, salt);
    if (candidate.length != stored.length) return false;
    var diff = 0;
    for (var i = 0; i < candidate.length; i++) {
      diff |= candidate.codeUnitAt(i) ^ stored.codeUnitAt(i);
    }
    return diff == 0;
  }

  static Future<void> clear(SharedPreferences p, String uid) async {
    await p.remove(_hashKey(uid));
    await p.remove(_saltKey(uid));
  }
}
