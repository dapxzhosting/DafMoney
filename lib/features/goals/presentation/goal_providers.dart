import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/session_providers.dart';
import '../data/goal_repository.dart';
import '../domain/savings_goal.dart';

final goalRepositoryProvider = Provider<GoalRepository>(
  (ref) => GoalRepository(ref.watch(firestoreProvider)),
);

final goalsProvider = StreamProvider<List<SavingsGoal>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const <SavingsGoal>[]);
  return ref.watch(goalRepositoryProvider).watch(uid);
});

class GoalActions {
  GoalActions(this._ref);

  final Ref _ref;

  String get _uid =>
      _ref.read(uidProvider) ??
      (throw const AppException('Sesi berakhir. Masuk lagi.'));

  GoalRepository get _repo => _ref.read(goalRepositoryProvider);

  Future<String?> add({
    required String name,
    required String iconKey,
    required int colorValue,
    required int target,
    required int saved,
    DateTime? deadline,
  }) => runGuarded(
    () => _repo.add(
      _uid,
      name: name,
      iconKey: iconKey,
      colorValue: colorValue,
      target: target,
      saved: saved,
      deadline: deadline,
    ),
  );

  Future<String?> update(
    String id, {
    required String name,
    required String iconKey,
    required int colorValue,
    required int target,
    DateTime? deadline,
  }) => runGuarded(
    () => _repo.update(
      _uid,
      id,
      name: name,
      iconKey: iconKey,
      colorValue: colorValue,
      target: target,
      deadline: deadline,
    ),
  );

  Future<String?> deposit(String id, int amount) =>
      runGuarded(() => _repo.adjustSaved(_uid, id, amount));

  Future<String?> withdraw(String id, int amount) =>
      runGuarded(() => _repo.adjustSaved(_uid, id, -amount));

  Future<String?> delete(String id) => runGuarded(() => _repo.delete(_uid, id));
}

final goalActionsProvider = Provider<GoalActions>((ref) => GoalActions(ref));
