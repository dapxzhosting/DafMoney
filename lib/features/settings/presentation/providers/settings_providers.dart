import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/providers/session_providers.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../reports/domain/report_calculator.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../data/settings_repository.dart';
import '../../domain/user_profile.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(firestoreProvider)),
);

final userProfileProvider = StreamProvider<UserProfile>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream<UserProfile>.empty();
  return ref.watch(settingsRepositoryProvider).watchProfile(uid);
});

class SettingsActions {
  SettingsActions(this._ref);

  final Ref _ref;

  String get _uid =>
      _ref.read(uidProvider) ?? (throw const AppException('Sesi berakhir. Masuk lagi.'));

  SettingsRepository get _repo => _ref.read(settingsRepositoryProvider);

  AuthRepository get _auth => _ref.read(authRepositoryProvider);

  Future<String?> updateName(String name) => runGuarded(() async {
        await _repo.updateName(_uid, name);
        await _auth.updateDisplayName(name);
      });

  Future<String?> setInitialBalance(int value) =>
      runGuarded(() => _repo.setInitialBalance(_uid, value));

  Future<String?> changePassword(String current, String next) =>
      runGuarded(() => _auth.changePassword(current: current, next: next));

  Future<String?> deleteAllTransactions() =>
      runGuarded(() => _repo.deleteAllTransactions(_uid));

  Future<String?> copyAllCsv() => runGuarded(() async {
        final txns =
            await _ref.read(transactionRepositoryProvider).fetchAll(_uid);
        if (txns.isEmpty) {
          throw const AppException('Belum ada transaksi untuk diekspor.');
        }
        final csv = buildCsv(txns, _ref.read(categoryMapProvider));
        await Clipboard.setData(ClipboardData(text: csv));
      });

  Future<String?> deleteAccount(String password) => runGuarded(() async {
        final uid = _uid;
        await _auth.reauthenticate(password);
        await _repo.deleteAllData(uid);
        try {
          await _auth.deleteCurrentUser();
        } catch (e) {
          throw AppException('Gagal menghapus akun: $e');
        }
      });
}

final settingsActionsProvider =
    Provider<SettingsActions>((ref) => SettingsActions(ref));
