import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../providers/shared_prefs_provider.dart';

/// Pilihan warna aksen. `null` = otomatis (warna sistem bila tersedia,
/// jika tidak memakai warna merek).
abstract class AccentOptions {
  static const List<Color> colors = [
    Color(0xFF0E9F6E), // hijau (merek)
    Color(0xFF2563EB), // biru
    Color(0xFF7C3AED), // ungu
    Color(0xFFDB2777), // merah muda
    Color(0xFFEA580C), // oranye
    Color(0xFF0891B2), // sian
  ];
}

class AccentNotifier extends Notifier<Color?> {
  @override
  Color? build() {
    final v = ref.read(sharedPrefsProvider).getInt(AppConstants.accentColorKey);
    return v == null ? null : Color(v);
  }

  Future<void> set(Color? color) async {
    state = color;
    final prefs = ref.read(sharedPrefsProvider);
    if (color == null) {
      await prefs.remove(AppConstants.accentColorKey);
    } else {
      await prefs.setInt(AppConstants.accentColorKey, color.toARGB32());
    }
  }
}

final accentProvider = NotifierProvider<AccentNotifier, Color?>(
  AccentNotifier.new,
);

class AmoledNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPrefsProvider).getBool(AppConstants.amoledKey) ?? false;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPrefsProvider).setBool(AppConstants.amoledKey, value);
  }
}

final amoledProvider = NotifierProvider<AmoledNotifier, bool>(
  AmoledNotifier.new,
);
