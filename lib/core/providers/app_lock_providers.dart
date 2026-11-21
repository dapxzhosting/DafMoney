import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import 'firebase_providers.dart';
import 'session_providers.dart';
import 'shared_prefs_provider.dart';
import '../../features/transactions/data/transaction_repository.dart' show writeSafe;

/// Apakah kunci aplikasi aktif. Disimpan di perangkat DAN disinkronkan ke akun Firestore.
class AppLockEnabled extends Notifier<bool> {
  /// True bila perubahan state terakhir berasal dari sinkronisasi Firestore,
  /// false bila dari tombol di Pengaturan.
  bool changedByRemote = false;

  @override
  bool build() {
    final uid = ref.watch(uidProvider);
    final prefs = ref.read(sharedPrefsProvider);
    final key = uid != null ? '${AppConstants.appLockKey}_$uid' : AppConstants.appLockKey;
    var localVal = prefs.getBool(key) ?? false;

    if (uid != null) {
      ref.listen<AsyncValue<DocumentSnapshot<Map<String, dynamic>>>>(
        userDocStreamProvider(uid),
        (previous, next) {
          final data = next.value?.data();
          if (data != null && data.containsKey('appLockEnabled')) {
            final remoteVal = data['appLockEnabled'] as bool?;
            if (remoteVal != null && remoteVal != state) {
              // Ditandai supaya AppLockGate tahu perubahan ini dari sinkronisasi.
              changedByRemote = true;
              state = remoteVal;
              ref.read(sharedPrefsProvider).setBool(key, remoteVal);
            }
          }
        },
      );

      // Listener di atas tidak terpanggil untuk data akun yang sudah termuat
      // sebelum provider ini dibuat (mis. setelah login di instalan baru),
      // jadi ambil nilainya langsung.
      final remote = loadedUserData(ref, uid)?['appLockEnabled'];
      if (remote is bool && remote != localVal) {
        localVal = remote;
        changedByRemote = true;
        prefs.setBool(key, remote);
      }
    }

    return localVal;
  }

  Future<void> set(bool value, {bool syncRemote = true}) async {
    changedByRemote = false;
    state = value;
    final uid = ref.read(uidProvider);
    final prefs = ref.read(sharedPrefsProvider);
    final key = uid != null ? '${AppConstants.appLockKey}_$uid' : AppConstants.appLockKey;
    await prefs.setBool(key, value);

    if (uid != null && syncRemote) {
      await writeSafe(
        () => ref.read(firestoreProvider).collection('users').doc(uid).set({
          'appLockEnabled': value,
        }, SetOptions(merge: true)),
      );
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
    final v = prefs.getInt(key);
    var localVal = options.contains(v) ? v! : 0;

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
            }
          }
        },
      );

      final remote = loadedUserData(ref, uid)?['appLockGrace'];
      if (remote is num && options.contains(remote.toInt())) {
        localVal = remote.toInt();
        prefs.setInt(key, localVal);
      }
    }

    return localVal;
  }

  Future<void> set(int seconds) async {
    state = seconds;
    final uid = ref.read(uidProvider);
    final prefs = ref.read(sharedPrefsProvider);
    final key = uid != null ? '${AppConstants.appLockGraceKey}_$uid' : AppConstants.appLockGraceKey;
    await prefs.setInt(key, seconds);

    if (uid != null) {
      await writeSafe(
        () => ref.read(firestoreProvider).collection('users').doc(uid).set({
          'appLockGrace': seconds,
        }, SetOptions(merge: true)),
      );
    }
  }
}

final appLockGraceProvider = NotifierProvider<AppLockGrace, int>(
  AppLockGrace.new,
);
