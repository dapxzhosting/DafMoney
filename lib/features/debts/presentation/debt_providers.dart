import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/session_providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/formatters.dart';
import '../data/debt_repository.dart';
import '../domain/debt.dart';

final debtRepositoryProvider = Provider<DebtRepository>(
  (ref) => DebtRepository(ref.watch(firestoreProvider)),
);

final debtsProvider = StreamProvider<List<Debt>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const <Debt>[]);
  return ref.watch(debtRepositoryProvider).watch(uid);
});

class DebtActions {
  DebtActions(this._ref);

  final Ref _ref;

  String get _uid =>
      _ref.read(uidProvider) ??
      (throw const AppException('Sesi berakhir. Masuk lagi.'));

  DebtRepository get _repo => _ref.read(debtRepositoryProvider);

  Future<void> _reschedule({
    required String id,
    required String person,
    required DebtKind kind,
    required int remaining,
    required DateTime? dueDate,
  }) async {
    final nid = NotificationService.idFor(id);
    try {
      await NotificationService.cancel(nid);
      if (dueDate == null || remaining <= 0) return;
      final isOwe = kind == DebtKind.owe;
      await NotificationService.scheduleOnce(
        id: nid,
        title: isOwe ? 'Utang jatuh tempo hari ini' : 'Piutang jatuh tempo',
        body: isOwe
            ? 'Bayar ${Fmt.rupiah(remaining)} ke $person.'
            : '$person belum membayar ${Fmt.rupiah(remaining)}.',
        when: DateTime(dueDate.year, dueDate.month, dueDate.day, 9),
      );
    } catch (_) {}
  }

  Future<String?> add({
    required String person,
    required DebtKind kind,
    required int amount,
    required String note,
    required DateTime date,
    DateTime? dueDate,
  }) => runGuarded(() async {
    final id = await _repo.add(
      _uid,
      person: person,
      kind: kind,
      amount: amount,
      note: note,
      date: date,
      dueDate: dueDate,
    );
    await _reschedule(
      id: id,
      person: person,
      kind: kind,
      remaining: amount,
      dueDate: dueDate,
    );
  });

  Future<String?> update(
    Debt old, {
    required String person,
    required DebtKind kind,
    required int amount,
    required String note,
    required DateTime date,
    DateTime? dueDate,
  }) => runGuarded(() async {
    await _repo.update(
      _uid,
      old,
      person: person,
      kind: kind,
      amount: amount,
      note: note,
      date: date,
      dueDate: dueDate,
    );
    await _reschedule(
      id: old.id,
      person: person,
      kind: kind,
      remaining: amount - old.paid,
      dueDate: dueDate,
    );
  });

  Future<String?> pay(Debt d, int delta) => runGuarded(() async {
    final paid = await _repo.adjustPaid(_uid, d.id, delta);
    await _reschedule(
      id: d.id,
      person: d.person,
      kind: d.kind,
      remaining: d.amount - paid,
      dueDate: d.dueDate,
    );
  });

  Future<String?> delete(Debt d) => runGuarded(() async {
    await _repo.delete(_uid, d.id);
    try {
      await NotificationService.cancel(NotificationService.idFor(d.id));
    } catch (_) {}
  });
}

final debtActionsProvider = Provider<DebtActions>((ref) => DebtActions(ref));
