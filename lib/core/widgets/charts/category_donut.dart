import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../features/categories/domain/category.dart';
import '../../../features/categories/presentation/category_style.dart';
import '../../../features/reports/domain/report_calculator.dart';
import '../../utils/formatters.dart';

class CategorySlice {
  const CategorySlice(this.label, this.color, this.value);

  final String label;
  final Color color;
  final int value;
}

/// Mengubah total per kategori menjadi irisan; sisanya digabung "Lainnya".
List<CategorySlice> buildSlices(
  List<CategoryTotal> totals,
  Map<String, Category> cats, {
  int max = 5,
}) {
  final slices = <CategorySlice>[];
  var rest = 0;
  for (var i = 0; i < totals.length; i++) {
    final t = totals[i];
    if (i < max) {
      final look = resolveCategory(cats, t.categoryId);
      slices.add(CategorySlice(look.name, look.color, t.total));
    } else {
      rest += t.total;
    }
  }
  if (rest > 0) {
    slices.add(CategorySlice('Lainnya', const Color(0xFF9CA3AF), rest));
  }
  return slices;
}

class CategoryDonut extends StatelessWidget {
  const CategoryDonut({
    super.key,
    required this.slices,
    required this.centerLabel,
  });

  final List<CategorySlice> slices;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final total = slices.fold<int>(0, (s, e) => s + e.value);

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 62,
                  startDegreeOffset: -90,
                  borderData: FlBorderData(show: false),
                  sections: [
                    for (final s in slices)
                      PieChartSectionData(
                        value: s.value.toDouble(),
                        color: s.color,
                        radius: 26,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(centerLabel,
                      style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(Fmt.rupiahCompact(total),
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final s in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: s.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium),
                ),
                Text(
                  total == 0 ? '0%' : Fmt.percent(s.value / total),
                  style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
