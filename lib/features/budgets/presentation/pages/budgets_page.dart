import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/entry_type.dart';
import '../../../../core/providers/session_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/month_selector.dart';
import '../../../categories/presentation/category_style.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../domain/budget.dart';
import '../providers/budget_providers.dart';
import '../widgets/budget_form_sheet.dart';

Color budgetColor(BuildContext context, BudgetStatus s) {
  final fin = context.finance;
  switch (s) {
    case BudgetStatus.safe:
      return fin.income;
    case BudgetStatus.warning:
      return fin.warning;
    case BudgetStatus.over:
      return fin.expense;
  }
}

class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  void _openAdd(BuildContext context, WidgetRef ref, List<BudgetProgress> current) {
    final month = ref.read(selectedMonthProvider);
    final cats = ref.read(categoriesProvider).valueOrNull ?? const [];
    final used = current.map((p) => p.budget.categoryId).toSet();
    final choices = cats
        .where((c) => c.type == EntryType.expense && !used.contains(c.id))
        .toList();
    if (choices.isEmpty) {
      context.showSnack(
          'Semua kategori pengeluaran sudah punya anggaran bulan ini.',
          error: true);
      return;
    }
    showBudgetSheet(context, month: month, choices: choices);
  }

  Future<void> _copy(BuildContext context, WidgetRef ref) async {
    final month = ref.read(selectedMonthProvider);
    final err =
        await ref.read(budgetActionsProvider).copyFromPreviousMonth(month);
    if (!context.mounted) return;
    context.showSnack(err ?? 'Anggaran bulan lalu berhasil disalin.',
        error: err != null);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(budgetProgressProvider);
    final cats = ref.watch(categoryMapProvider);
    final month = ref.watch(selectedMonthProvider);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Anggaran')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _openAdd(context, ref, progress.valueOrNull ?? const []),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Anggaran'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: MonthSelector(),
          ),
          Expanded(
            child: AsyncView<List<BudgetProgress>>(
              value: progress,
              data: (list) {
                if (list.isEmpty) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      EmptyState(
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'Belum ada anggaran',
                        message:
                            'Atur batas pengeluaran per kategori untuk ${Fmt.monthYear(month)}.',
                        actionLabel: 'Tambah anggaran',
                        onAction: () => _openAdd(context, ref, list),
                      ),
                      TextButton(
                        onPressed: () => _copy(context, ref),
                        child: const Text('Salin dari bulan lalu'),
                      ),
                    ],
                  );
                }

                final totalBudget =
                    list.fold<int>(0, (s, p) => s + p.budget.amount);
                final totalSpent = list.fold<int>(0, (s, p) => s + p.spent);
                final overall =
                    totalBudget == 0 ? 0.0 : totalSpent / totalBudget;
                final overallStatus = overall >= 1
                    ? BudgetStatus.over
                    : (overall >= 0.8 ? BudgetStatus.warning : BudgetStatus.safe);
                final overallColor = budgetColor(context, overallStatus);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total terpakai',
                                style: tt.labelLarge
                                    ?.copyWith(color: cs.onSurfaceVariant)),
                            const SizedBox(height: 4),
                            Text(
                              '${Fmt.rupiah(totalSpent)} / ${Fmt.rupiah(totalBudget)}',
                              style: tt.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 12),
                            _Bar(value: overall, color: overallColor),
                            const SizedBox(height: 8),
                            Text(
                              totalBudget - totalSpent >= 0
                                  ? 'Sisa ${Fmt.rupiah(totalBudget - totalSpent)}'
                                  : 'Melebihi ${Fmt.rupiah(totalSpent - totalBudget)}',
                              style: tt.bodySmall?.copyWith(
                                  color: overallColor,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final p in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _BudgetCard(
                          progress: p,
                          onTap: () => showBudgetSheet(
                            context,
                            month: month,
                            choices: const [],
                            existing: p.budget,
                            existingCategory: cats[p.budget.categoryId],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0).toDouble()),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => LinearProgressIndicator(
          value: v,
          minHeight: 10,
          color: color,
          backgroundColor: cs.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  const _BudgetCard({required this.progress, required this.onTap});

  final BudgetProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final cats = ref.watch(categoryMapProvider);
    final look = resolveCategory(cats, progress.budget.categoryId);
    final color = budgetColor(context, progress.status);
    final over = progress.remaining < 0;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CategoryAvatar(icon: look.icon, color: look.color, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(look.name,
                            style: tt.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          '${Fmt.rupiah(progress.spent)} dari ${Fmt.rupiah(progress.budget.amount)}',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Fmt.percent(progress.ratio),
                    style: tt.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Bar(value: progress.ratio, color: color),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  over
                      ? 'Melebihi ${Fmt.rupiah(-progress.remaining)}'
                      : 'Sisa ${Fmt.rupiah(progress.remaining)}',
                  style: tt.bodySmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
