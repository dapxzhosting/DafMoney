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

final receiptProvider = FutureProvider.autoDispose.family<Uint8List?, String>((
  ref,
  transactionId,
) async {
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

final txTotalsByWalletProvider =
    StreamProvider.autoDispose<Map<String, Balance>>((ref) {
      final uid = ref.watch(uidProvider);
      if (uid == null) return Stream.value(const <String, Balance>{});
      return ref.watch(transactionRepositoryProvider).watchTotalsByWallet(uid);
    });

final balanceProvider = Provider.autoDispose<AsyncValue<Balance>>((ref) {
  return ref.watch(txTotalsByWalletProvider).whenData((byWallet) {
    var income = 0;
    var expense = 0;
    for (final b in byWallet.values) {
      income += b.income;
      expense += b.expense;
    }
    return Balance(income: income, expense: expense);
  });
});

class TransactionActions {
  TransactionActions(this._ref);

  final Ref _ref;

  String get _uid =>
      _ref.read(uidProvider) ??
      (throw const AppException('Sesi berakhir. Masuk lagi.'));

  TransactionRepository get _repo => _ref.read(transactionRepositoryProvider);

  ReceiptRepository get _receipts => _ref.read(receiptRepositoryProvider);

  Future<String?> add({
    required EntryType type,
    required int amount,
    required String categoryId,
    required String note,
    required DateTime date,
    String? walletId,
    Uint8List? receipt,
  }) => runGuarded(() async {
    if (receipt != null) ReceiptRepository.ensureSize(receipt);
    final id = await _repo.add(
      _uid,
      type: type,
      amount: amount,
      categoryId: categoryId,
      note: note,
      date: date,
      walletId: walletId,
      hasReceipt: receipt != null,
    );
    if (receipt != null) {
      try {
        await _receipts.save(_uid, id, receipt);
      } catch (_) {
        try {
          await _repo.delete(_uid, id);
        } catch (_) {}
        rethrow;
      }
    }
  });

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
  }) => runGuarded(() async {
    if (newReceipt != null) ReceiptRepository.ensureSize(newReceipt);
    if (newReceipt != null) await _receipts.save(_uid, id, newReceipt);
    await _repo.update(
      _uid,
      id,
      type: type,
      amount: amount,
      categoryId: categoryId,
      note: note,
      date: date,
      walletId: walletId,
      hasReceipt: newReceipt != null || keepReceipt,
    );
    if (newReceipt == null && !keepReceipt && hadReceipt) {
      await _receipts.delete(_uid, id);
    }
    _ref.invalidate(receiptProvider(id));
  });

  Future<String?> delete(String id) => runGuarded(() async {
    await _repo.delete(_uid, id);
  });

  Future<Uint8List?> receiptBytes(String id) async {
    try {
      return await _receipts.fetch(_uid, id);
    } catch (_) {
      return null;
    }
  }

  Future<String?> restore(MoneyTransaction t, {Uint8List? receipt}) =>
      runGuarded(() async {
        await _repo.restore(_uid, t, hasReceipt: receipt != null);
        if (receipt != null) await _receipts.save(_uid, t.id, receipt);
      });

  Future<({String? error, String? id})> duplicate(MoneyTransaction t) async {
    String? newId;
    final err = await runGuarded(() async {
      newId = await _repo.add(
        _uid,
        type: t.type,
        amount: t.amount,
        categoryId: t.categoryId,
        note: t.note,
        date: DateTime.now(),
        walletId: t.walletId,
      );
    });
    return (error: err, id: newId);
  }
}

final transactionActionsProvider = Provider<TransactionActions>(
  (ref) => TransactionActions(ref),
);
