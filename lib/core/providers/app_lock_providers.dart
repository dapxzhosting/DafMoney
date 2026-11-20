import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import 'shared_prefs_provider.dart';

/// Apakah kunci aplikasi aktif. Disimpan di perangkat (bukan di akun).
class AppLockEnabled extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPrefsProvider).getBool(AppConstants.appLockKey) ?? false;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPrefsProvider).setBool(AppConstants.appLockKey, value);
  }
}

final appLockEnabledProvider = NotifierProvider<AppLockEnabled, bool>(
  AppLockEnabled.new,
);

/// Berapa detik aplikasi boleh di latar belakang sebelum terkunci lagi.
/// 0 = langsung terkunci begitu ditinggalkan.
class AppLockGrace extends Notifier<int> {
  static const options = [0, 60, 300];

  @override
  int build() {
    final v = ref.read(sharedPrefsProvider).getInt(AppConstants.appLockGraceKey);
    return options.contains(v) ? v! : 0;
  }

  Future<void> set(int seconds) async {
    state = seconds;
    await ref
        .read(sharedPrefsProvider)
        .setInt(AppConstants.appLockGraceKey, seconds);
  }
}

final appLockGraceProvider = NotifierProvider<AppLockGrace, int>(
  AppLockGrace.new,
);
