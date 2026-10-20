import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../transactions/domain/money_transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';

enum ReportPeriod {
  thisMonth('Bulan ini'),
  lastMonth('Bulan lalu'),
  last3Months('3 bulan'),
  thisYear('Tahun ini'),
  custom('Kustom');

  const ReportPeriod(this.label);

  final String label;
}

class ReportFilter extends Equatable {
  const ReportFilter(this.period, [this.custom]);

  final ReportPeriod period;
  final DateRange? custom;

  DateRange get range {
    final n = DateTime.now();
    switch (period) {
      case ReportPeriod.thisMonth:
        return DateRange.month(n);
      case ReportPeriod.lastMonth:
        return DateRange.month(DateTime(n.year, n.month - 1));
      case ReportPeriod.last3Months:
        return DateRange(DateTime(n.year, n.month - 2), DateTime(n.year, n.month + 1));
      case ReportPeriod.thisYear:
        return DateRange(DateTime(n.year), DateTime(n.year + 1));
      case ReportPeriod.custom:
        return custom ?? DateRange.month(n);
    }
  }

  @override
  List<Object?> get props => [period, custom];
}

class ReportFilterNotifier extends Notifier<ReportFilter> {
  @override
  ReportFilter build() => const ReportFilter(ReportPeriod.thisMonth);

  void setPeriod(ReportPeriod p) => state = ReportFilter(p, state.custom);

  void setCustom(DateTime first, DateTime last) {
    state = ReportFilter(
      ReportPeriod.custom,
      DateRange(dateOnly(first), DateTime(last.year, last.month, last.day + 1)),
    );
  }
}

final reportFilterProvider =
    NotifierProvider<ReportFilterNotifier, ReportFilter>(
        ReportFilterNotifier.new);

final reportTransactionsProvider =
    Provider.autoDispose<AsyncValue<List<MoneyTransaction>>>((ref) {
  final range = ref.watch(reportFilterProvider).range;
  return ref.watch(transactionsByRangeProvider(range));
});
