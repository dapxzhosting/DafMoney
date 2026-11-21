import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/models/entry_type.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/session_providers.dart';
import '../../../core/services/notification_service.dart';
import '../data/recurring_repository.dart';
import '../domain/recurring_entry.dart';

final recurringRepositoryProvider = Provider<RecurringRepository>(
  (ref) => RecurringRepository(ref.watch(firestoreProvider)),
);

final recurringListProvider = StreamProvider<List<RecurringEntry>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const <RecurringEntry>[]);
  return ref.watch(recurringRepositoryProvider).watch(uid);
});

class RecurringActions {
  RecurringActions(this._ref);

  final Ref _ref;
  bool _running = false;

  String get _uid =>
      _ref.read(uidProvider) ??
      (throw const AppException('Sesi berakhir. Masuk lagi.'));

  RecurringRepository get _repo => _ref.read(recurringRepositoryProvider);

  Future<void> processDue() async {
    final uid = _ref.read(uidProvider);
    if (uid == null || _running) return;
    _running = true;
    try {
      final n = await _repo.processDue(uid);
      if (n > 0) {
        _ref.read(dataVersionProvider.notifier).bump();
        try {
          await NotificationService.showInfo(
            title: 'Transaksi berulang dicatat',
            body: '$n transaksi otomatis ditambahkan ke catatan Anda.',
          );
        } catch (_) {}
      }
    } catch (_) {
    } finally {
      _running = false;
    }
  }

  Future<String?> add({
    required EntryType type,
    required int amount,
    required String categoryId,
    required String note,
    required Frequency frequency,
    required DateTime startDate,
    String? walletId,
  }) => runGuarded(() async {
    await _repo.add(
      _uid,
      type: type,
      amount: amount,
      categoryId: categoryId,
      note: note,
      frequency: frequency,
      startDate: startDate,
      walletId: walletId,
    );
    await processDue();
  });

  Future<String?> update(
    RecurringEntry old, {
    required EntryType type,
    required int amount,
    required String categoryId,
    required String note,
    required Frequency frequency,
    required DateTime startDate,
    String? walletId,
  }) => runGuarded(
    () => _repo.update(
      _uid,
      old,
      type: type,
      amount: amount,
      categoryId: categoryId,
      note: note,
      frequency: frequency,
      startDate: startDate,
      walletId: walletId,
    ),
  );

  Future<String?> setActive(String id, bool active) =>
      runGuarded(() => _repo.setActive(_uid, id, active));

  Future<String?> delete(String id) => runGuarded(() => _repo.delete(_uid, id));
}

final recurringActionsProvider = Provider<RecurringActions>(
  (ref) => RecurringActions(ref),
);
