import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/session_providers.dart';
import '../../../core/providers/shared_prefs_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../../transactions/presentation/providers/history_provider.dart';
import '../domain/no_spend_challenge.dart';

/// Tantangan aktif (disimpan lokal & disinkronkan ke akun Cloud Firestore).
class ChallengeNotifier extends Notifier<NoSpendChallenge?> {
  String? get _key {
    final uid = ref.read(uidProvider);
    return uid == null ? null : '${AppConstants.challengeKey}_$uid';
  }

  @override
  NoSpendChallenge? build() {
    final uid = ref.watch(uidProvider);
    if (uid == null) return null;

    final key = '${AppConstants.challengeKey}_$uid';
    final raw = ref.read(sharedPrefsProvider).getString(key);

    // Sync tantangan & streak dari akun Firestore saat login / instal ulang aplikasi
    ref.listen<AsyncValue<DocumentSnapshot<Map<String, dynamic>>>>(
      userDocStreamProvider(uid),
      (previous, next) {
        final data = next.value?.data();
        if (data != null && data.containsKey('challenge')) {
          final cMap = data['challenge'];
          if (cMap is Map<String, dynamic>) {
            try {
              final remoteChallenge = NoSpendChallenge.fromJson(cMap);
              if (state != remoteChallenge) {
                state = remoteChallenge;
                ref
                    .read(sharedPrefsProvider)
                    .setString(key, jsonEncode(remoteChallenge.toJson()));
              }
            } catch (_) {}
          } else if (cMap == null && state != null) {
            state = null;
            ref.read(sharedPrefsProvider).remove(key);
          }
        }
      },
    );

    if (raw != null) {
      try {
        return NoSpendChallenge.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {}
    }
    return null;
  }

  Future<void> _save(NoSpendChallenge? c) async {
    state = c;
    final uid = ref.read(uidProvider);
    if (uid == null) return;
    final key = '${AppConstants.challengeKey}_$uid';
    final prefs = ref.read(sharedPrefsProvider);
    if (c == null) {
      await prefs.remove(key);
      await ref.read(firestoreProvider).collection('users').doc(uid).set({
        'challenge': FieldValue.delete(),
      }, SetOptions(merge: true));
    } else {
      final json = c.toJson();
      await prefs.setString(key, jsonEncode(json));
      await ref.read(firestoreProvider).collection('users').doc(uid).set({
        'challenge': json,
      }, SetOptions(merge: true));
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
