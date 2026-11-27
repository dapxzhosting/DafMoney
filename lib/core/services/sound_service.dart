import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Efek suara singkat ("dongg") saat transaksi berhasil dicatat.
/// Aman dipanggil dari engine utama maupun popup "Catat cepat".
class SoundService {
  SoundService._();

  static AudioPlayer? _player;
  static bool _contextSet = false;

  static Future<bool> _enabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      return prefs.getBool(AppConstants.soundEnabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> _play() async {
    if (!_contextSet) {
      _contextSet = true;
      // Jangan menghentikan musik yang sedang diputar pengguna.
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build(),
      );
    }
    final p = _player ??= AudioPlayer();
    await p.setReleaseMode(ReleaseMode.stop);
    await p.stop();
    await p.play(AssetSource('sounds/dong.wav'), volume: 0.9);
  }

  /// Putar hanya jika efek suara diaktifkan di pengaturan.
  static Future<void> playDong() async {
    try {
      if (!await _enabled()) return;
      await _play();
    } catch (_) {}
  }

  /// Putar tanpa cek pengaturan (untuk pratinjau saat saklar dinyalakan).
  static Future<void> preview() async {
    try {
      await _play();
    } catch (_) {}
  }
}
