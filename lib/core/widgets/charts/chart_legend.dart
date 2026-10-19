import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final fin = context.finance;
    final tt = Theme.of(context).textTheme;

    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: tt.labelMedium),
          ],
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        item(fin.income, 'Pemasukan'),
        const SizedBox(width: 20),
        item(fin.expense, 'Pengeluaran'),
      ],
    );
  }
}
