import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../features/reports/domain/report_calculator.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import 'chart_legend.dart';

/// Grafik garis harian pemasukan & pengeluaran (untuk rentang <= 31 hari).
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({super.key, required this.data});

  final List<DayTotal> data;

  LineChartBarData _line(List<FlSpot> spots, Color color) => LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.2,
        preventCurveOverShooting: true,
        color: color,
        barWidth: 3,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: color.withValues(alpha: 0.10),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fin = context.finance;

    final n = data.length;
    final maxV = data.fold<int>(0, (m, e) => max(m, max(e.income, e.expense)));
    final maxY = maxV == 0 ? 1.0 : maxV * 1.25;
    final step = max(1, (n / 6).ceil()).toDouble();

    final income = [
      for (var i = 0; i < n; i++) FlSpot(i.toDouble(), data[i].income.toDouble())
    ];
    final expense = [
      for (var i = 0; i < n; i++) FlSpot(i.toDouble(), data[i].expense.toDouble())
    ];

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: max(1, n - 1).toDouble(),
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: step,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= n) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${data[i].day.day}',
                          style: tt.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => cs.inverseSurface,
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem(
                        Fmt.rupiah(s.y),
                        TextStyle(
                          color: cs.onInverseSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                _line(income, fin.income),
                _line(expense, fin.expense),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const ChartLegend(),
      ],
    );
  }
}
