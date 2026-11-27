import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import 'shared_prefs_provider.dart';

class SoundEnabledNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPrefsProvider).getBool(AppConstants.soundEnabledKey) ??
      true;

  Future<void> set(bool value) async {
    state = value;
    await ref
        .read(sharedPrefsProvider)
        .setBool(AppConstants.soundEnabledKey, value);
  }
}

final soundEnabledProvider = NotifierProvider<SoundEnabledNotifier, bool>(
  SoundEnabledNotifier.new,
);
