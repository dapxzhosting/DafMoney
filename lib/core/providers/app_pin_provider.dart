import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_pin_service.dart';
import 'session_providers.dart';
import 'shared_prefs_provider.dart';

/// State = apakah akun ini punya PIN aplikasi.
class AppPinNotifier extends Notifier<bool> {
  String? get _uid => ref.read(uidProvider);

  @override
  bool build() {
    final uid = ref.watch(uidProvider);
    if (uid == null) return false;
    return AppPinService.has(ref.read(sharedPrefsProvider), uid);
  }

  bool verify(String pin) {
    final uid = _uid;
    if (uid == null) return false;
    return AppPinService.verify(ref.read(sharedPrefsProvider), uid, pin);
  }

  Future<void> setPin(String pin) async {
    final uid = _uid;
    if (uid == null) return;
    await AppPinService.set(ref.read(sharedPrefsProvider), uid, pin);
    state = true;
  }

  Future<void> clear() async {
    final uid = _uid;
    if (uid == null) return;
    await AppPinService.clear(ref.read(sharedPrefsProvider), uid);
    state = false;
  }
}

final appPinProvider = NotifierProvider<AppPinNotifier, bool>(
  AppPinNotifier.new,
);
