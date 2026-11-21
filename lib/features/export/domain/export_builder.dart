import 'dart:math' as math;

import '../../../core/models/entry_type.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_style.dart';
import '../../reports/domain/report_calculator.dart';
import '../../transactions/domain/money_transaction.dart';
import '../../wallets/domain/wallet.dart';
import 'export_report.dart';

abstract class ExportRanges {
  static DateRange forScope(
    ExportScope scope, {
    required DateTime month,
    required int year,
    DateRange? custom,
  }) {
    switch (scope) {
      case ExportScope.month:
        return DateRange.month(month);
      case ExportScope.year:
        return DateRange(DateTime(year), DateTime(year + 1));
      case ExportScope.allYears:
        return DateRange(DateTime(2000), DateTime(DateTime.now().year + 1));
      case ExportScope.custom:
        return custom ?? DateRange.month(month);
    }
  }
}

ExportReport buildExportReport({
  required ExportScope scope,
  required DateRange range,
  required List<MoneyTransaction> txns,
  required Map<String, Category> cats,
  required Map<String, Wallet> wallets,
}) {
  final summary = summarize(txns);

  final sorted = [...txns]..sort((a, b) => a.date.compareTo(b.date));

  final entries = [
    for (final t in sorted)
      ExportEntry(
        date: t.date,
        type: t.type,
        categoryName: resolveCategory(cats, t.categoryId).name,
        note: t.note.trim(),
        walletName: wallets[t.walletId]?.name ?? '-',
        amount: t.amount,
      ),
  ];

  List<ExportCategory> categoryList(EntryType type) {
    final totals = byCategory(txns, type);
    final sum = totals.fold<int>(0, (s, c) => s + c.total);
    return [
      for (final c in totals)
        ExportCategory(
          name: resolveCategory(cats, c.categoryId).name,
          color: resolveCategory(cats, c.categoryId).color,
          total: c.total,
          ratio: sum == 0 ? 0 : c.total / sum,
        ),
    ];
  }

  final today = dateOnly(DateTime.now());
  final tomorrow = DateTime(today.year, today.month, today.day + 1);
  final start = scope == ExportScope.allYears && sorted.isNotEmpty
      ? dateOnly(sorted.first.date)
      : range.start;
  final end = range.end.isAfter(tomorrow) ? tomorrow : range.end;
  final days = math.max(1, end.difference(start).inDays);

  final first = sorted.isEmpty ? DateTime.now() : sorted.first.date;
  final last = sorted.isEmpty ? DateTime.now() : sorted.last.date;

  late final String title;
  late final String periodLabel;
  late final String bucketTitle;
  late final String slug;
  late final List<ExportBucket> buckets;

  switch (scope) {
    case ExportScope.month:
      title = 'Laporan Bulanan';
      periodLabel = Fmt.monthYear(range.start);
      bucketTitle = 'Ringkasan per minggu';
      slug =
          '${range.start.year}-${range.start.month.toString().padLeft(2, '0')}';
      buckets = _weekly(txns, range, rangeLabels: true);
    case ExportScope.year:
      title = 'Laporan Tahunan';
      periodLabel = 'Tahun ${range.start.year}';
      bucketTitle = 'Ringkasan per bulan';
      slug = '${range.start.year}';
      buckets = [
        for (final m in byMonth(txns, DateTime(range.start.year), 12))
          ExportBucket(Fmt.monthShort(m.month), m.income, m.expense),
      ];
    case ExportScope.allYears:
      title = 'Laporan Seluruh Riwayat';
      periodLabel = first.year == last.year
          ? '${first.year}'
          : '${first.year} - ${last.year}';
      bucketTitle = 'Ringkasan per tahun';
      slug = 'semua-tahun';
      buckets = _yearly(txns, first.year, last.year);
    case ExportScope.custom:
      final lastDay = DateTime(
        range.end.year,
        range.end.month,
        range.end.day - 1,
      );
      title = 'Laporan Periode';
      periodLabel = '${Fmt.dateShort(range.start)} - ${Fmt.dateShort(lastDay)}';
      slug =
          '${monthKey(range.start)}-sd-${monthKey(lastDay)}-${lastDay.day.toString().padLeft(2, '0')}';
      if (range.days <= 92) {
        bucketTitle = 'Ringkasan per minggu';
        buckets = _weekly(txns, range, rangeLabels: false);
      } else {
        bucketTitle = 'Ringkasan per bulan';
        final months =
            (lastDay.year - range.start.year) * 12 +
            lastDay.month -
            range.start.month +
            1;
        buckets = [
          for (final m in byMonth(
            txns,
            DateTime(range.start.year, range.start.month),
            months,
          ))
            ExportBucket(
              '${Fmt.monthShort(m.month)} ${m.month.year % 100}',
              m.income,
              m.expense,
            ),
        ];
      }
  }

  return ExportReport(
    scope: scope,
    title: title,
    periodLabel: periodLabel,
    bucketTitle: bucketTitle,
    fileSlug: slug,
    generatedAt: DateTime.now(),
    income: summary.income,
    expense: summary.expense,
    buckets: buckets,
    expenseCategories: categoryList(EntryType.expense),
    incomeCategories: categoryList(EntryType.income),
    entries: entries,
    avgDailyExpense: (summary.expense / days).round(),
    savingsRate: summary.income <= 0 ? null : summary.net / summary.income,
  );
}

List<ExportBucket> _weekly(
  List<MoneyTransaction> txns,
  DateRange range, {
  required bool rangeLabels,
}) {
  final n = (range.days / 7).ceil();
  final inc = List<int>.filled(n, 0);
  final exp = List<int>.filled(n, 0);
  final origin = dateOnly(range.start);
  for (final t in txns) {
    final idx = dateOnly(t.date).difference(origin).inDays ~/ 7;
    if (idx < 0 || idx >= n) continue;
    if (t.type == EntryType.income) {
      inc[idx] += t.amount;
    } else {
      exp[idx] += t.amount;
    }
  }
  return [
    for (var i = 0; i < n; i++)
      ExportBucket(_weekLabel(range, i, rangeLabels), inc[i], exp[i]),
  ];
}

String _weekLabel(DateRange range, int i, bool rangeLabels) {
  final s = DateTime(
    range.start.year,
    range.start.month,
    range.start.day + i * 7,
  );
  if (!rangeLabels) return '${s.day}/${s.month}';
  var e = DateTime(s.year, s.month, s.day + 6);
  if (e.isAfter(range.end.subtract(const Duration(days: 1)))) {
    e = range.end.subtract(const Duration(days: 1));
  }
  return '${s.day}-${e.day}';
}

List<ExportBucket> _yearly(
  List<MoneyTransaction> txns,
  int firstYear,
  int lastYear,
) {
  final inc = <int, int>{};
  final exp = <int, int>{};
  for (final t in txns) {
    final y = t.date.year;
    if (t.type == EntryType.income) {
      inc[y] = (inc[y] ?? 0) + t.amount;
    } else {
      exp[y] = (exp[y] ?? 0) + t.amount;
    }
  }
  return [
    for (var y = firstYear; y <= lastYear; y++)
      ExportBucket('$y', inc[y] ?? 0, exp[y] ?? 0),
  ];
}
