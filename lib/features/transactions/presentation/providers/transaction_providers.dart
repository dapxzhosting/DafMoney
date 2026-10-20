import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/models/entry_type.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/providers/session_providers.dart';
import '../../../../core/utils/date_utils.dart';
import '../../data/transaction_repository.dart';
import '../../domain/money_transaction.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => TransactionRepository(ref.watch(firestoreProvider)),
);

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

  void _bump() => _ref.read(dataVersionProvider.notifier).bump();

  Future<String?> add({
    required EntryType type,
    required int amount,
    required String categoryId,
    required String note,
    required DateTime date,
  }) =>
      runGuarded(() async {
        await _repo.add(_uid,
            type: type,
            amount: amount,
            categoryId: categoryId,
            note: note,
            date: date);
        _bump();
      });

  Future<String?> update(
    String id, {
    required EntryType type,
    required int amount,
    required String categoryId,
    required String note,
    required DateTime date,
  }) =>
      runGuarded(() async {
        await _repo.update(_uid, id,
            type: type,
            amount: amount,
            categoryId: categoryId,
            note: note,
            date: date);
        _bump();
      });

  Future<String?> delete(String id) => runGuarded(() async {
        await _repo.delete(_uid, id);
        _bump();
      });
}

final transactionActionsProvider =
    Provider<TransactionActions>((ref) => TransactionActions(ref));
