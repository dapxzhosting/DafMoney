import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/models/entry_type.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/providers/session_providers.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../data/budget_repository.dart';
import '../../domain/budget.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(firestoreProvider)),
);

final monthBudgetsProvider =
    StreamProvider.autoDispose<List<Budget>>((ref) {
  final uid = ref.watch(uidProvider);
  final month = ref.watch(selectedMonthProvider);
  if (uid == null) return Stream.value(const <Budget>[]);
  return ref.watch(budgetRepositoryProvider).watchMonth(uid, monthKey(month));
});

final budgetProgressProvider =
    Provider.autoDispose<AsyncValue<List<BudgetProgress>>>((ref) {
  final budgets = ref.watch(monthBudgetsProvider);
  final txns = ref.watch(monthTransactionsProvider);

  if (budgets.hasError && !budgets.hasValue) {
    return AsyncError(budgets.error!, budgets.stackTrace ?? StackTrace.current);
  }
  if (txns.hasError && !txns.hasValue) {
    return AsyncError(txns.error!, txns.stackTrace ?? StackTrace.current);
  }
  if (!budgets.hasValue || !txns.hasValue) return const AsyncLoading();

  final spent = <String, int>{};
  for (final t in txns.requireValue) {
    if (t.type != EntryType.expense) continue;
    spent[t.categoryId] = (spent[t.categoryId] ?? 0) + t.amount;
  }
  final list = [
    for (final b in budgets.requireValue)
      BudgetProgress(b, spent[b.categoryId] ?? 0),
  ]..sort((a, b) => b.ratio.compareTo(a.ratio));
  return AsyncData(list);
});

class BudgetActions {
  BudgetActions(this._ref);

  final Ref _ref;

  String get _uid =>
      _ref.read(uidProvider) ?? (throw const AppException('Sesi berakhir. Masuk lagi.'));

  BudgetRepository get _repo => _ref.read(budgetRepositoryProvider);

  Future<String?> save({
    required String categoryId,
    required DateTime month,
    required int amount,
  }) =>
      runGuarded(() => _repo.upsert(_uid,
          categoryId: categoryId, month: monthKey(month), amount: amount));

  Future<String?> delete(String id) => runGuarded(() => _repo.delete(_uid, id));

  Future<String?> copyFromPreviousMonth(DateTime month) => runGuarded(
        () => _repo.copyMonth(
          _uid,
          from: monthKey(DateTime(month.year, month.month - 1)),
          to: monthKey(month),
        ),
      );
}

final budgetActionsProvider =
    Provider<BudgetActions>((ref) => BudgetActions(ref));
