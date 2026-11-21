import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/providers/session_providers.dart';
import '../../../transactions/domain/money_transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../../transfers/domain/wallet_transfer.dart';
import '../../../transfers/presentation/transfer_providers.dart';
import '../../data/wallet_repository.dart';
import '../../domain/wallet.dart';

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => WalletRepository(ref.watch(firestoreProvider)),
);

final walletsProvider = StreamProvider<List<Wallet>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const <Wallet>[]);
  return ref.watch(walletRepositoryProvider).watch(uid);
});

final walletMapProvider = Provider<Map<String, Wallet>>((ref) {
  final list = ref.watch(walletsProvider).valueOrNull ?? const <Wallet>[];
  return {for (final w in list) w.id: w};
});

final walletsInitialSumProvider = Provider<int>((ref) {
  final list = ref.watch(walletsProvider).valueOrNull ?? const <Wallet>[];
  return list.fold<int>(0, (sum, w) => sum + w.initialBalance);
});

final walletTotalsProvider =
    Provider.autoDispose<AsyncValue<Map<String, Balance>>>((ref) {
      final base = ref.watch(txTotalsByWalletProvider);
      final transfers =
          ref.watch(transfersProvider).valueOrNull ?? const <WalletTransfer>[];
      return base.whenData((m) => mergeTransfers(m, transfers));
    });

class WalletActions {
  WalletActions(this._ref);

  final Ref _ref;

  String get _uid =>
      _ref.read(uidProvider) ??
      (throw const AppException('Sesi berakhir. Masuk lagi.'));

  WalletRepository get _repo => _ref.read(walletRepositoryProvider);

  Future<String?> add({
    required String name,
    required String iconKey,
    required int colorValue,
    required int initialBalance,
  }) => runGuarded(
    () => _repo.add(
      _uid,
      name: name,
      iconKey: iconKey,
      colorValue: colorValue,
      initialBalance: initialBalance,
    ),
  );

  Future<String?> update(
    String id, {
    required String name,
    required String iconKey,
    required int colorValue,
    required int initialBalance,
  }) => runGuarded(
    () => _repo.update(
      _uid,
      id,
      name: name,
      iconKey: iconKey,
      colorValue: colorValue,
      initialBalance: initialBalance,
    ),
  );

  Future<String?> delete(String id) => runGuarded(() async {
    await _repo.delete(_uid, id);
    _ref.read(dataVersionProvider.notifier).bump();
  });
}

final walletActionsProvider = Provider<WalletActions>(
  (ref) => WalletActions(ref),
);
