import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import 'firebase_providers.dart';
import 'session_providers.dart';
import 'shared_prefs_provider.dart';

/// Apakah kunci aplikasi aktif. Disimpan di perangkat DAN disinkronkan ke akun Firestore.
class AppLockEnabled extends Notifier<bool> {
  @override
  bool build() {
    final uid = ref.watch(uidProvider);
    final prefs = ref.read(sharedPrefsProvider);
    final key = uid != null ? '${AppConstants.appLockKey}_$uid' : AppConstants.appLockKey;
    final localVal = prefs.getBool(key) ?? prefs.getBool(AppConstants.appLockKey) ?? false;

    if (uid != null) {
      ref.listen<AsyncValue<DocumentSnapshot<Map<String, dynamic>>>>(
        userDocStreamProvider(uid),
        (previous, next) {
          final data = next.value?.data();
          if (data != null && data.containsKey('appLockEnabled')) {
            final remoteVal = data['appLockEnabled'] as bool?;
            if (remoteVal != null && remoteVal != state) {
              state = remoteVal;
              ref.read(sharedPrefsProvider).setBool(key, remoteVal);
              ref.read(sharedPrefsProvider).setBool(AppConstants.appLockKey, remoteVal);
            }
          }
        },
      );
    }

    return localVal;
  }

  Future<void> set(bool value) async {
    state = value;
    final uid = ref.read(uidProvider);
    final prefs = ref.read(sharedPrefsProvider);
    final key = uid != null ? '${AppConstants.appLockKey}_$uid' : AppConstants.appLockKey;
    await prefs.setBool(key, value);
    await prefs.setBool(AppConstants.appLockKey, value);

    if (uid != null) {
      await ref.read(firestoreProvider).collection('users').doc(uid).set({
        'appLockEnabled': value,
      }, SetOptions(merge: true));
    }
  }
}

final appLockEnabledProvider = NotifierProvider<AppLockEnabled, bool>(
  AppLockEnabled.new,
);

/// Berapa detik aplikasi boleh di latar belakang sebelum terkunci lagi.
class AppLockGrace extends Notifier<int> {
  static const options = [0, 60, 300];

  @override
  int build() {
    final uid = ref.watch(uidProvider);
    final prefs = ref.read(sharedPrefsProvider);
    final key = uid != null ? '${AppConstants.appLockGraceKey}_$uid' : AppConstants.appLockGraceKey;
    final v = prefs.getInt(key) ?? prefs.getInt(AppConstants.appLockGraceKey);
    final localVal = options.contains(v) ? v! : 0;

    if (uid != null) {
      ref.listen<AsyncValue<DocumentSnapshot<Map<String, dynamic>>>>(
        userDocStreamProvider(uid),
        (previous, next) {
          final data = next.value?.data();
          if (data != null && data.containsKey('appLockGrace')) {
            final remoteVal = (data['appLockGrace'] as num?)?.toInt();
            if (remoteVal != null && options.contains(remoteVal) && remoteVal != state) {
              state = remoteVal;
              ref.read(sharedPrefsProvider).setInt(key, remoteVal);
              ref.read(sharedPrefsProvider).setInt(AppConstants.appLockGraceKey, remoteVal);
            }
          }
        },
      );
    }

    return localVal;
  }

  Future<void> set(int seconds) async {
    state = seconds;
    final uid = ref.read(uidProvider);
    final prefs = ref.read(sharedPrefsProvider);
    final key = uid != null ? '${AppConstants.appLockGraceKey}_$uid' : AppConstants.appLockGraceKey;
    await prefs.setInt(key, seconds);
    await prefs.setInt(AppConstants.appLockGraceKey, seconds);

    if (uid != null) {
      await ref.read(firestoreProvider).collection('users').doc(uid).set({
        'appLockGrace': seconds,
      }, SetOptions(merge: true));
    }
  }
}

final appLockGraceProvider = NotifierProvider<AppLockGrace, int>(
  AppLockGrace.new,
);
