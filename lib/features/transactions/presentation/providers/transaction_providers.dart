import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/models/entry_type.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/providers/session_providers.dart';
import '../../../../core/utils/date_utils.dart';
import '../../data/receipt_repository.dart';
import '../../data/transaction_repository.dart';
import '../../domain/money_transaction.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(firestoreProvider)),
);

final receiptRepositoryProvider = Provider<ReceiptRepository>(
  (ref) => ReceiptRepository(ref.watch(firestoreProvider)),
);

/// Foto struk satu transaksi (null jika tidak ada).
final receiptProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((ref, transactionId) async {
  final uid = ref.watch(uidProvider);
  if (uid == null) return null;
  return ref.watch(receiptRepositoryProvider).fetch(uid, transactionId);
});

final transactionsByRangeProvider = StreamProvider.autoDispose
    .family<List<MoneyTransaction>, DateRange>((ref, range) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const <MoneyTransaction>[]);
  return ref.watch(transactionRepositoryProvider).watchRange(uid, range);
});

final monthTransactionsProvider =
    Provider.autoDispose<AsyncValue<List<MoneyTransaction>>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return ref.watch(transactionsByRangeProvider(DateRange.month(month)));
});

final balanceProvider = StreamProvider.autoDispose<Balance>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(Balance.zero);
  return ref.watch(transactionRepositoryProvider).watchTotals(uid);
});

class TransactionActions {
  TransactionActions(this._ref);

  final Ref _ref;

  String get _uid =>
      _ref.read(uidProvider) ?? (throw const AppException('Sesi berakhir. Masuk lagi.'));

  TransactionRepository get _repo => _ref.read(transactionRepositoryProvider);

  ReceiptRepository get _receipts => _ref.read(receiptRepositoryProvider);

  void _bump() => _ref.read(dataVersionProvider.notifier).bump();

  Future<String?> add({
    required EntryType type,
    required int amount,
    required String categoryId,
    required String note,
    required DateTime date,
    String? walletId,
    Uint8List? receipt,
  }) =>
      runGuarded(() async {
        if (receipt != null) ReceiptRepository.ensureSize(receipt);
        final id = await _repo.add(_uid,
            type: type,
            amount: amount,
            categoryId: categoryId,
            note: note,
            date: date,
            walletId: walletId,
            hasReceipt: receipt != null);
        if (receipt != null) await _receipts.save(_uid, id, receipt);
        _bump();
      });

  /// [newReceipt]: foto baru yang menggantikan foto lama.
  /// [keepReceipt]: pertahankan foto lama (jika tidak ada [newReceipt]).
  /// [hadReceipt]: transaksi ini sebelumnya punya foto struk.
  Future<String?> update(
    String id, {
    required EntryType type,
    required int amount,
    required String categoryId,
    required String note,
    required DateTime date,
    String? walletId,
    Uint8List? newReceipt,
    bool keepReceipt = false,
    bool hadReceipt = false,
  }) =>
      runGuarded(() async {
        if (newReceipt != null) ReceiptRepository.ensureSize(newReceipt);
        if (newReceipt != null) await _receipts.save(_uid, id, newReceipt);
        await _repo.update(_uid, id,
            type: type,
            amount: amount,
            categoryId: categoryId,
            note: note,
            date: date,
            walletId: walletId,
            hasReceipt: newReceipt != null || keepReceipt);
        if (newReceipt == null && !keepReceipt && hadReceipt) {
          await _receipts.delete(_uid, id);
        }
        _ref.invalidate(receiptProvider(id));
        _bump();
      });

  Future<String?> delete(String id) => runGuarded(() async {
        await _repo.delete(_uid, id);
        _bump();
      });
}

final transactionActionsProvider =
    Provider<TransactionActions>((ref) => TransactionActions(ref));
