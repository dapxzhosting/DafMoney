import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_utils.dart';
import '../../domain/money_transaction.dart';
import 'transaction_providers.dart';

/// 6 bulan terakhir (sampai akhir bulan ini). Rentangnya sama dengan dashboard
/// saat bulan berjalan dipilih, jadi data dipakai bersama tanpa baca ulang.
final recentHistoryRangeProvider = Provider.autoDispose<DateRange>((ref) {
  final n = DateTime.now();
  return DateRange(
    DateTime(n.year, n.month - 5),
    DateTime(n.year, n.month + 1),
  );
});

final recentHistoryProvider = Provider.autoDispose<List<MoneyTransaction>>((
  ref,
) {
  final range = ref.watch(recentHistoryRangeProvider);
  return ref.watch(transactionsByRangeProvider(range)).valueOrNull ??
      const <MoneyTransaction>[];
});
