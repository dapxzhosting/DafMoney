import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/entry_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/category_avatar.dart';
import '../../../core/widgets/charts/category_donut.dart';
import '../../../core/widgets/charts/month_bar_chart.dart';
import '../../../core/widgets/charts/trend_line_chart.dart';
import '../../../core/widgets/empty_state.dart';
import '../../categories/presentation/category_style.dart';
import '../../categories/presentation/providers/category_providers.dart';
import '../../transactions/domain/money_transaction.dart';
import '../../transactions/presentation/providers/transaction_providers.dart';
import '../domain/report_calculator.dart';
import 'providers/report_providers.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  EntryType _breakdownType = EntryType.expense;

  Future<void> _pickCustom() async {
    final range = ref.read(reportFilterProvider).range;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: range.start,
        end: range.end.subtract(const Duration(days: 1)),
      ),
    );
    if (picked != null) {
      ref.read(reportFilterProvider.notifier).setCustom(picked.start, picked.end);
    }
  }

  Future<void> _exportCsv() async {
    final txns = ref.read(reportTransactionsProvider).valueOrNull;
    if (txns == null || txns.isEmpty) {
      context.showSnack('Tidak ada data untuk diekspor.', error: true);
      return;
    }
    final csv = buildCsv(txns, ref.read(categoryMapProvider));
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    context.showSnack('${txns.length} transaksi disalin sebagai CSV. Tempel ke Excel/Sheets.');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final filter = ref.watch(reportFilterProvider);
    final txAsync = ref.watch(reportTransactionsProvider);
    final cats = ref.watch(categoryMapProvider);
    final range = filter.range;
    final lastDay = range.end.subtract(const Duration(days: 1));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        actions: [
          IconButton(
            tooltip: 'Salin sebagai CSV',
            onPressed: _exportCsv,
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final p in ReportPeriod.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(p.label),
                      selected: filter.period == p,
                      onSelected: (_) {
                        if (p == ReportPeriod.custom) {
                          _pickCustom();
                        } else {
                          ref.read(reportFilterProvider.notifier).setPeriod(p);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${Fmt.dateShort(range.start)} – ${Fmt.dateShort(lastDay)}',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          AsyncView<List<MoneyTransaction>>(
            value: txAsync,
            onRetry: () => ref.invalidate(transactionsByRangeProvider),
            data: (all) {
              if (all.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.insert_chart_outlined_rounded,
                    title: 'Belum ada data',
                    message: 'Tidak ada transaksi pada periode ini.',
                  ),
                );
              }
              final summary = summarize(all);
              final fin = context.finance;
              final months = (lastDay.year - range.start.year) * 12 +
                  lastDay.month -
                  range.start.month +
                  1;
              final breakdown = byCategory(all, _breakdownType);
              final slices = buildSlices(breakdown, cats);
              final breakdownTotal =
                  breakdown.fold<int>(0, (s, e) => s + e.total);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Stat('Pemasukan', summary.income, fin.income),
                      const SizedBox(width: 10),
                      _Stat('Pengeluaran', summary.expense, fin.expense),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Selisih',
                                    style: tt.labelMedium?.copyWith(
                                        color: cs.onSurfaceVariant)),
                                const SizedBox(height: 4),
                                Text(
                                  '${summary.net >= 0 ? '+' : '-'}${Fmt.rupiah(summary.net.abs())}',
                                  style: tt.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: summary.net >= 0
                                        ? fin.income
                                        : fin.expense,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (summary.income > 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Rasio tabungan',
                                    style: tt.labelMedium?.copyWith(
                                        color: cs.onSurfaceVariant)),
                                const SizedBox(height: 4),
                                Text(
                                  Fmt.percent(summary.savingsRate),
                                  style: tt.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Arus kas',
                    child: range.days <= 31
                        ? TrendLineChart(data: byDay(all, range))
                        : MonthBarChart(
                            data: byMonth(
                              all,
                              DateTime(range.start.year, range.start.month),
                              months,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Rincian kategori',
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<EntryType>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                  value: EntryType.expense,
                                  label: Text('Pengeluaran')),
                              ButtonSegment(
                                  value: EntryType.income,
                                  label: Text('Pemasukan')),
                            ],
                            selected: {_breakdownType},
                            onSelectionChanged: (s) =>
                                setState(() => _breakdownType = s.first),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (breakdown.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Tidak ada ${_breakdownType.label.toLowerCase()} pada periode ini.',
                              style: tt.bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          )
                        else ...[
                          CategoryDonut(
                            slices: slices,
                            centerLabel: _breakdownType.label,
                          ),
                          const Divider(height: 28),
                          for (final c in breakdown)
                            _BreakdownRow(
                              total: c,
                              percent: breakdownTotal == 0
                                  ? 0
                                  : c.total / breakdownTotal,
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(Fmt.rupiah(value),
                    style: tt.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800, color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends ConsumerWidget {
  const _BreakdownRow({required this.total, required this.percent});

  final CategoryTotal total;
  final double percent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final look = resolveCategory(ref.watch(categoryMapProvider), total.categoryId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              CategoryAvatar(icon: look.icon, color: look.color, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(look.name,
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Fmt.rupiah(total.total),
                      style: tt.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(Fmt.percent(percent),
                      style: tt.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent.clamp(0.0, 1.0).toDouble(),
              minHeight: 6,
              color: look.color,
              backgroundColor: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
