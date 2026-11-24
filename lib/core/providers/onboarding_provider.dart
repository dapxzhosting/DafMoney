import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import 'account_sync.dart';
import 'firebase_providers.dart';
import 'session_providers.dart';
import 'shared_prefs_provider.dart';

class OnboardingNotifier extends Notifier<bool> {
  static const _field = 'onboardingDone';

  @override
  bool build() {
    final prefs = ref.read(sharedPrefsProvider);
    final local = prefs.getBool(AppConstants.onboardingDoneKey) ?? false;
    final uid = ref.watch(uidProvider);
    if (uid != null) {
      ref.listen<AsyncValue<DocumentSnapshot<Map<String, dynamic>>>>(
        userDocStreamProvider(uid),
        (_, next) {
          final data = next.valueOrNull?.data();
          if (data == null) return;
          final remote = data[_field] == true;
          if (remote && !state) {
            state = true;
            prefs.setBool(AppConstants.onboardingDoneKey, true);
          } else if (!remote && state) {
            syncToAccount(ref.read(firestoreProvider), uid, {_field: true});
          }
        },
      );
    }
    return local;
  }

  Future<void> complete() async {
    state = true;
    await ref
        .read(sharedPrefsProvider)
        .setBool(AppConstants.onboardingDoneKey, true);
    final uid = ref.read(uidProvider);
    if (uid != null) {
      await syncToAccount(ref.read(firestoreProvider), uid, {_field: true});
    }
  }
}

final onboardingDoneProvider = NotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);
