import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_providers.dart';

final uidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).valueOrNull?.uid,
);

class SelectedMonth extends Notifier<DateTime> {
  @override
  DateTime build() {
    final n = DateTime.now();
    return DateTime(n.year, n.month);
  }

  void shift(int delta) => state = DateTime(state.year, state.month + delta);

  void reset() {
    final n = DateTime.now();
    state = DateTime(n.year, n.month);
  }
}

final selectedMonthProvider =
    NotifierProvider<SelectedMonth, DateTime>(SelectedMonth.new);

class DataVersion extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final dataVersionProvider =
    NotifierProvider<DataVersion, int>(DataVersion.new);
