import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/entry_type.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../transactions/domain/money_transaction.dart';
import '../../../transactions/presentation/widgets/transaction_tile.dart';
import '../../../wallets/presentation/providers/wallet_providers.dart';
import '../../domain/report_calculator.dart';

/// Kalender panas pengeluaran: tiap hari diwarnai menurut besar pengeluaran.
/// Ketuk sebuah hari untuk melihat transaksinya.
class ExpenseHeatmap extends ConsumerStatefulWidget {
  const ExpenseHeatmap({super.key, required this.range, required this.txns});

  final DateRange range;
  final List<MoneyTransaction> txns;

  @override
  ConsumerState<ExpenseHeatmap> createState() => _ExpenseHeatmapState();
}

class _ExpenseHeatmapState extends ConsumerState<ExpenseHeatmap> {
  DateTime? _selected;

  @override
  void didUpdateWidget(ExpenseHeatmap old) {
    super.didUpdateWidget(old);
    if (old.range != widget.range) _selected = null;
  }

  static const _weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fin = context.finance;

    final range = widget.range;
    final days = byDay(widget.txns, range);
    final today = dateOnly(DateTime.now());
    final maxExpense = days.fold<int>(0, (m, d) => math.max(m, d.expense));

    final offset = (range.start.weekday - 1) % 7;
    final rows = ((offset + days.length) / 7).ceil();
    final waveKey = ValueKey('${range.start}-${range.end}');

    Color levelColor(int level) {
      if (level == 0) return cs.surfaceContainerHighest.withValues(alpha: 0.7);
      final t = level / 4;
      return Color.lerp(fin.expense.withValues(alpha: 0.25), fin.expense, t)!;
    }

    int levelOf(int expense) {
      if (expense <= 0 || maxExpense <= 0) return 0;
      return (expense / maxExpense * 4).ceil().clamp(1, 4).toInt();
    }

    Widget cell(int index, int row, int col) {
      final di = index - offset;
      if (di < 0 || di >= days.length) return const SizedBox.shrink();
      final d = days[di];
      final future = d.day.isAfter(today);
      final level = future ? 0 : levelOf(d.expense);
      final isToday = isSameDay(d.day, today);
      final selected = _selected != null && isSameDay(_selected!, d.day);
      final strong = level >= 3;

      return AnimatedScale(
            scale: selected ? 1.12 : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: GestureDetector(
              onTap: future
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      setState(() => _selected = selected ? null : d.day);
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: future
                      ? cs.surfaceContainerHighest.withValues(alpha: 0.25)
                      : levelColor(level),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? cs.onSurface
                        : (isToday ? cs.primary : Colors.transparent),
                    width: selected ? 2.2 : 1.8,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${d.day.day}',
                  style: tt.labelSmall?.copyWith(
                    fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                    color: future
                        ? cs.onSurfaceVariant.withValues(alpha: 0.4)
                        : (strong ? Colors.white : cs.onSurface),
                  ),
                ),
              ),
            ),
          )
          .animate(key: waveKey)
          .fadeIn(delay: (row * 55 + col * 30).ms, duration: 320.ms)
          .scale(
            begin: const Offset(0.4, 0.4),
            delay: (row * 55 + col * 30).ms,
            duration: 380.ms,
            curve: Curves.easeOutBack,
          );
    }

    // Statistik ringkas.
    DayTotal? peak;
    var activeDays = 0;
    var totalExpense = 0;
    var frugal = 0;
    for (final d in days) {
      if (d.day.isAfter(today)) continue;
      if (d.expense > 0) {
        activeDays++;
        totalExpense += d.expense;
        if (peak == null || d.expense > peak.expense) peak = d;
      } else {
        frugal++;
      }
    }
    final avgActive = activeDays == 0 ? 0 : (totalExpense / activeDays).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < rows; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: cell(r * 7 + c, r, c),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Hemat',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 6),
            for (var l = 0; l <= 4; l++)
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: levelColor(l),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            const SizedBox(width: 6),
            Text(
              'Boros',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _MiniStat(
              label: 'Paling boros',
              value: peak == null ? '-' : Fmt.rupiahCompact(peak.expense),
              sub: peak == null ? null : Fmt.dateShort(peak.day),
            ),
            const SizedBox(width: 8),
            _MiniStat(
              label: 'Rata-rata aktif',
              value: Fmt.rupiahCompact(avgActive),
              sub: 'per hari belanja',
            ),
            const SizedBox(width: 8),
            _MiniStat(
              label: 'Hari hemat',
              value: '$frugal',
              sub: 'tanpa pengeluaran',
            ),
          ],
        ).animate(key: waveKey).fadeIn(delay: 500.ms, duration: 400.ms),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: _selected == null
                ? Padding(
                    key: const ValueKey('hint'),
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      'Ketuk sebuah tanggal untuk melihat transaksinya.',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  )
                : _DayPanel(
                    key: ValueKey(_selected),
                    day: _selected!,
                    txns: widget.txns
                        .where((t) => isSameDay(t.date, _selected!))
                        .toList(),
                  ),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.sub});

  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (sub != null)
              Text(
                sub!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayPanel extends ConsumerWidget {
  const _DayPanel({super.key, required this.day, required this.txns});

  final DateTime day;
  final List<MoneyTransaction> txns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fin = context.finance;
    final cats = ref.watch(categoryMapProvider);
    final wallets = ref.watch(walletMapProvider);
    final s = summarize(txns);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    Fmt.dateLong(day),
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (s.expense > 0)
                  Text(
                    '-${Fmt.rupiah(s.expense)}',
                    style: tt.labelLarge?.copyWith(
                      color: fin.expense,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (txns.isEmpty)
              Text(
                'Tidak ada transaksi di hari ini.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              )
            else
              for (final t in txns)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TransactionTile(
                    transaction: t,
                    categories: cats,
                    wallets: wallets,
                    onTap: () =>
                        context.push(AppRoutes.transactionForm, extra: t),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
