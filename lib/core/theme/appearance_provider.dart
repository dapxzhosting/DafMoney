import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../providers/account_sync.dart';
import '../providers/firebase_providers.dart';
import '../providers/session_providers.dart';
import '../providers/shared_prefs_provider.dart';

abstract class AccentOptions {
  static const List<Color> colors = [
    Color(0xFF0E9F6E),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFFEA580C),
    Color(0xFF0891B2),
  ];
}

class AccentNotifier extends Notifier<Color?> {
  static const _field = 'accentColor';

  static Color? _fromRemote(int v) => v == 0 ? null : Color(v);

  @override
  Color? build() {
    final prefs = ref.read(sharedPrefsProvider);
    final v = prefs.getInt(AppConstants.accentColorKey);
    var color = v == null ? null : Color(v);

    final uid = ref.watch(uidProvider);
    if (uid == null) return color;

    ref.listen<AsyncValue<DocumentSnapshot<Map<String, dynamic>>>>(
      userDocStreamProvider(uid),
      (_, next) {
        final snap = next.valueOrNull;
        final data = snap?.data();
        if (snap == null || data == null) return;
        final raw = data[_field];
        if (raw is int) {
          final remote = _fromRemote(raw);
          if (remote?.toARGB32() != state?.toARGB32()) {
            state = remote;
            _saveLocal(remote);
          }
        } else if (state != null && isSettledServerSnapshot(snap)) {
          syncToAccount(ref.read(firestoreProvider), uid, {
            _field: state!.toARGB32(),
          });
        }
      },
    );

    final raw = loadedUserData(ref, uid)?[_field];
    if (raw is int) {
      color = _fromRemote(raw);
      _saveLocal(color);
    }
    return color;
  }

  Future<void> _saveLocal(Color? color) async {
    final prefs = ref.read(sharedPrefsProvider);
    if (color == null) {
      await prefs.remove(AppConstants.accentColorKey);
    } else {
      await prefs.setInt(AppConstants.accentColorKey, color.toARGB32());
    }
  }

  Future<void> set(Color? color) async {
    state = color;
    await _saveLocal(color);
    final uid = ref.read(uidProvider);
    if (uid != null) {
      await syncToAccount(ref.read(firestoreProvider), uid, {
        _field: color?.toARGB32() ?? 0,
      });
    }
  }
}

final accentProvider = NotifierProvider<AccentNotifier, Color?>(
  AccentNotifier.new,
);

class AmoledNotifier extends Notifier<bool> {
  static const _field = 'amoled';

  @override
  bool build() {
    final prefs = ref.read(sharedPrefsProvider);
    var value = prefs.getBool(AppConstants.amoledKey) ?? false;

    final uid = ref.watch(uidProvider);
    if (uid == null) return value;

    ref.listen<AsyncValue<DocumentSnapshot<Map<String, dynamic>>>>(
      userDocStreamProvider(uid),
      (_, next) {
        final snap = next.valueOrNull;
        final data = snap?.data();
        if (snap == null || data == null) return;
        final raw = data[_field];
        if (raw is bool) {
          if (raw != state) {
            state = raw;
            prefs.setBool(AppConstants.amoledKey, raw);
          }
        } else if (state && isSettledServerSnapshot(snap)) {
          syncToAccount(ref.read(firestoreProvider), uid, {_field: state});
        }
      },
    );

    final raw = loadedUserData(ref, uid)?[_field];
    if (raw is bool) {
      value = raw;
      prefs.setBool(AppConstants.amoledKey, raw);
    }
    return value;
  }

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPrefsProvider).setBool(AppConstants.amoledKey, value);
    final uid = ref.read(uidProvider);
    if (uid != null) {
      await syncToAccount(ref.read(firestoreProvider), uid, {_field: value});
    }
  }
}

final amoledProvider = NotifierProvider<AmoledNotifier, bool>(
  AmoledNotifier.new,
);
