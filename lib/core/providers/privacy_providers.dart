import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import 'shared_prefs_provider.dart';

/// Apakah angka saldo disembunyikan (dikunci di perangkat, bukan di akun).
class HideBalanceNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPrefsProvider).getBool(AppConstants.hideBalanceKey) ??
      false;

  Future<void> toggle() async {
    state = !state;
    await ref
        .read(sharedPrefsProvider)
        .setBool(AppConstants.hideBalanceKey, state);
  }
}

final hideBalanceProvider =
    NotifierProvider<HideBalanceNotifier, bool>(HideBalanceNotifier.new);
