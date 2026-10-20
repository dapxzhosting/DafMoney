import 'package:intl/intl.dart';

import '../../../core/models/entry_type.dart';
import '../../../core/utils/date_utils.dart';
import '../../categories/domain/category.dart';
import '../../transactions/domain/money_transaction.dart';

class PeriodSummary {
  const PeriodSummary(this.income, this.expense);

  final int income;
  final int expense;

  int get net => income - expense;

  double get savingsRate => income <= 0 ? 0 : net / income;
}

class CategoryTotal {
  const CategoryTotal(this.categoryId, this.total);

  final String categoryId;
  final int total;
}

class MonthTotal {
  const MonthTotal(this.month, this.income, this.expense);

  final DateTime month;
  final int income;
  final int expense;
}

class DayTotal {
  const DayTotal(this.day, this.income, this.expense);

  final DateTime day;
  final int income;
  final int expense;
}

PeriodSummary summarize(List<MoneyTransaction> txns) {
  var inc = 0;
  var exp = 0;
  for (final t in txns) {
    if (t.type == EntryType.income) {
      inc += t.amount;
    } else {
      exp += t.amount;
    }
  }
  return PeriodSummary(inc, exp);
}

List<CategoryTotal> byCategory(List<MoneyTransaction> txns, EntryType type) {
  final map = <String, int>{};
  for (final t in txns) {
    if (t.type != type) continue;
    map[t.categoryId] = (map[t.categoryId] ?? 0) + t.amount;
  }
  final list = [for (final e in map.entries) CategoryTotal(e.key, e.value)]
    ..sort((a, b) => b.total.compareTo(a.total));
  return list;
}

List<MonthTotal> byMonth(
    List<MoneyTransaction> txns, DateTime firstMonth, int count) {
  final inc = List<int>.filled(count, 0);
  final exp = List<int>.filled(count, 0);
  for (final t in txns) {
    final idx =
        (t.date.year - firstMonth.year) * 12 + t.date.month - firstMonth.month;
    if (idx < 0 || idx >= count) continue;
    if (t.type == EntryType.income) {
      inc[idx] += t.amount;
    } else {
      exp[idx] += t.amount;
    }
  }
  return [
    for (var i = 0; i < count; i++)
      MonthTotal(DateTime(firstMonth.year, firstMonth.month + i), inc[i], exp[i]),
  ];
}

List<DayTotal> byDay(List<MoneyTransaction> txns, DateRange range) {
  final n = range.days;
  final inc = List<int>.filled(n, 0);
  final exp = List<int>.filled(n, 0);
  final start = dateOnly(range.start);
  for (final t in txns) {
    final idx = dateOnly(t.date).difference(start).inDays;
    if (idx < 0 || idx >= n) continue;
    if (t.type == EntryType.income) {
      inc[idx] += t.amount;
    } else {
      exp[idx] += t.amount;
    }
  }
  return [
    for (var i = 0; i < n; i++)
      DayTotal(DateTime(start.year, start.month, start.day + i), inc[i], exp[i]),
  ];
}

String buildCsv(List<MoneyTransaction> txns, Map<String, Category> cats) {
  String esc(String s) => '"${s.replaceAll('"', '""')}"';
  final df = DateFormat('yyyy-MM-dd');
  final sorted = [...txns]..sort((a, b) => a.date.compareTo(b.date));
  final sb = StringBuffer('Tanggal,Jenis,Kategori,Jumlah,Catatan\n');
  for (final t in sorted) {
    sb.writeln([
      df.format(t.date),
      t.type.label,
      esc(cats[t.categoryId]?.name ?? 'Tanpa kategori'),
      t.amount,
      esc(t.note),
    ].join(','));
  }
  return sb.toString();
}
