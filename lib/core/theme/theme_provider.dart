import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../providers/account_sync.dart';
import '../providers/firebase_providers.dart';
import '../providers/session_providers.dart';
import '../providers/shared_prefs_provider.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _field = 'themeMode';

  static ThemeMode? _parse(Object? raw) {
    for (final m in ThemeMode.values) {
      if (m.name == raw) return m;
    }
    return null;
  }

  @override
  ThemeMode build() {
    final prefs = ref.read(sharedPrefsProvider);
    var mode =
        _parse(prefs.getString(AppConstants.themeModeKey)) ?? ThemeMode.system;

    final uid = ref.watch(uidProvider);
    if (uid == null) return mode;

    ref.listen<AsyncValue<DocumentSnapshot<Map<String, dynamic>>>>(
      userDocStreamProvider(uid),
      (_, next) {
        final snap = next.valueOrNull;
        final data = snap?.data();
        if (snap == null || data == null) return;
        final remote = _parse(data[_field]);
        if (remote != null) {
          if (remote != state) {
            state = remote;
            prefs.setString(AppConstants.themeModeKey, remote.name);
          }
        } else if (state != ThemeMode.system && isSettledServerSnapshot(snap)) {
          syncToAccount(ref.read(firestoreProvider), uid, {_field: state.name});
        }
      },
    );

    final remote = _parse(loadedUserData(ref, uid)?[_field]);
    if (remote != null) {
      mode = remote;
      prefs.setString(AppConstants.themeModeKey, remote.name);
    }
    return mode;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref
        .read(sharedPrefsProvider)
        .setString(AppConstants.themeModeKey, mode.name);
    final uid = ref.read(uidProvider);
    if (uid != null) {
      await syncToAccount(ref.read(firestoreProvider), uid, {
        _field: mode.name,
      });
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
