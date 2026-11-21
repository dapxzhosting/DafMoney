import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/session_providers.dart';
import '../data/transfer_repository.dart';
import '../domain/wallet_transfer.dart';

final transferRepositoryProvider = Provider<TransferRepository>(
  (ref) => TransferRepository(ref.watch(firestoreProvider)),
);

final transfersProvider = StreamProvider<List<WalletTransfer>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const <WalletTransfer>[]);
  return ref.watch(transferRepositoryProvider).watch(uid);
});

class TransferActions {
  TransferActions(this._ref);

  final Ref _ref;

  String get _uid =>
      _ref.read(uidProvider) ??
      (throw const AppException('Sesi berakhir. Masuk lagi.'));

  Future<String?> add({
    required String fromWalletId,
    required String toWalletId,
    required int amount,
    required String note,
    required DateTime date,
  }) => runGuarded(() async {
    if (fromWalletId == toWalletId) {
      throw const AppException('Dompet asal dan tujuan harus berbeda.');
    }
    await _ref
        .read(transferRepositoryProvider)
        .add(
          _uid,
          fromWalletId: fromWalletId,
          toWalletId: toWalletId,
          amount: amount,
          note: note,
          date: date,
        );
  });

  Future<String?> delete(String id) =>
      runGuarded(() => _ref.read(transferRepositoryProvider).delete(_uid, id));
}

final transferActionsProvider = Provider<TransferActions>(
  (ref) => TransferActions(ref),
);
