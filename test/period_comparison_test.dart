import 'package:daf_money/core/models/entry_type.dart';
import 'package:daf_money/features/export/domain/export_builder.dart';
import 'package:daf_money/features/export/domain/export_report.dart';
import 'package:daf_money/features/transactions/domain/money_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

MoneyTransaction _tx(DateTime date) => MoneyTransaction(
  id: date.toIso8601String(),
  type: EntryType.expense,
  amount: 1000,
  categoryId: 'c',
  note: '',
  date: date,
  createdAt: date,
);

void main() {
  final now = DateTime(2026, 6, 15);

  test('bulan yang sudah lewat dibandingkan dengan bulan sebelumnya penuh', () {
    final all = [
      _tx(DateTime(2025, 2, 5)),
      _tx(DateTime(2025, 2, 28)),
      _tx(DateTime(2025, 3, 10)),
    ];
    final prev = previousPeriodTxns(
      scope: ExportScope.month,
      start: DateTime(2025, 3),
      all: all,
      now: now,
    );
    expect(prev.length, 2);
  });

  test('bulan berjalan dibandingkan sampai tanggal yang sama', () {
    final all = [
      _tx(DateTime(2026, 5, 10)),
      _tx(DateTime(2026, 5, 20)),
      _tx(DateTime(2026, 6, 1)),
    ];
    final prev = previousPeriodTxns(
      scope: ExportScope.month,
      start: DateTime(2026, 6),
      all: all,
      now: now,
    );
    expect(prev.length, 1);
  });

  test('tahun berjalan dibandingkan sampai tanggal yang sama', () {
    final all = [
      _tx(DateTime(2025, 3, 1)),
      _tx(DateTime(2025, 6, 15)),
      _tx(DateTime(2025, 6, 16)),
      _tx(DateTime(2025, 12, 1)),
    ];
    final prev = previousPeriodTxns(
      scope: ExportScope.year,
      start: DateTime(2026),
      all: all,
      now: now,
    );
    expect(prev.length, 2);
  });

  test('tahun yang sudah lewat dibandingkan dengan tahun sebelumnya penuh', () {
    final all = [_tx(DateTime(2024, 12, 31)), _tx(DateTime(2024, 1, 1))];
    final prev = previousPeriodTxns(
      scope: ExportScope.year,
      start: DateTime(2025),
      all: all,
      now: now,
    );
    expect(prev.length, 2);
  });

  test('cakupan lain tidak punya pembanding', () {
    final prev = previousPeriodTxns(
      scope: ExportScope.custom,
      start: DateTime(2026),
      all: [_tx(DateTime(2025, 5, 5))],
      now: now,
    );
    expect(prev, isEmpty);
  });
}
