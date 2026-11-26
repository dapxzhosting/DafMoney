import 'package:daf_money/features/reports/domain/report_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rasio tabungan null saat tidak ada pemasukan', () {
    expect(const PeriodSummary(0, 5000).savingsRate, isNull);
  });

  test('rasio tabungan dihitung dari pemasukan', () {
    expect(const PeriodSummary(10000, 4000).savingsRate, closeTo(0.6, 1e-9));
    expect(const PeriodSummary(10000, 12000).savingsRate, closeTo(-0.2, 1e-9));
  });
}
