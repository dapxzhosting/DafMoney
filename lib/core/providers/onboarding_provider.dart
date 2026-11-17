import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import 'shared_prefs_provider.dart';

/// true bila pengguna sudah melihat / melewati onboarding di perangkat ini.
class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPrefsProvider).getBool(AppConstants.onboardingDoneKey) ??
      false;

  Future<void> complete() async {
    state = true;
    await ref
        .read(sharedPrefsProvider)
        .setBool(AppConstants.onboardingDoneKey, true);
  }
}

final onboardingDoneProvider = NotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);
