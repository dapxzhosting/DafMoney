import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/shared_prefs_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../../transactions/presentation/providers/history_provider.dart';
import '../domain/no_spend_challenge.dart';

/// Tantangan aktif (tersimpan di perangkat). null = belum ada.
class ChallengeNotifier extends Notifier<NoSpendChallenge?> {
  @override
  NoSpendChallenge? build() {
    final raw = ref
        .read(sharedPrefsProvider)
        .getString(AppConstants.challengeKey);
    if (raw == null) return null;
    try {
      return NoSpendChallenge.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save(NoSpendChallenge? c) async {
    state = c;
    final prefs = ref.read(sharedPrefsProvider);
    if (c == null) {
      await prefs.remove(AppConstants.challengeKey);
    } else {
      await prefs.setString(AppConstants.challengeKey, jsonEncode(c.toJson()));
    }
  }

  /// Memulai tantangan baru mulai hari ini. [carryBest] menjaga rekor lama.
  Future<void> start({
    required String categoryId,
    required int targetDays,
    int carryBest = 0,
  }) {
    return _save(
      NoSpendChallenge(
        categoryId: categoryId,
        startDate: dateOnly(DateTime.now()),
        targetDays: targetDays,
        bestEver: carryBest,
      ),
    );
  }

  Future<void> stop() => _save(null);
}

final challengeProvider =
    NotifierProvider<ChallengeNotifier, NoSpendChallenge?>(
      ChallengeNotifier.new,
    );

/// Kemajuan tantangan, dihitung dari riwayat 6 bulan terakhir.
final challengeProgressProvider = Provider.autoDispose<ChallengeProgress?>((
  ref,
) {
  final c = ref.watch(challengeProvider);
  if (c == null) return null;
  final history = ref.watch(recentHistoryProvider);
  return computeChallenge(c, history);
});
