import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_providers.dart';

/// UID pengguna yang sedang login (null jika belum).
final uidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).valueOrNull?.uid,
);

/// Bulan yang sedang dilihat (dipakai Beranda, Transaksi, Anggaran).
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

/// Dinaikkan setelah data transaksi berubah, agar saldo total dihitung ulang.
class DataVersion extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final dataVersionProvider =
    NotifierProvider<DataVersion, int>(DataVersion.new);
