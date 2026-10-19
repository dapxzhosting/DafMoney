import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/entry_type.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/session_providers.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/category_avatar.dart';
import '../../../core/widgets/charts/category_donut.dart';
import '../../../core/widgets/charts/month_bar_chart.dart';
import '../../../core/widgets/month_selector.dart';
import '../../budgets/domain/budget.dart';
import '../../budgets/presentation/pages/budgets_page.dart';
import '../../budgets/presentation/providers/budget_providers.dart';
import '../../categories/presentation/category_style.dart';
import '../../categories/presentation/providers/category_providers.dart';
import '../../reports/domain/report_calculator.dart';
import '../../transactions/domain/money_transaction.dart';
import '../../transactions/presentation/providers/transaction_providers.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';

/// 6 bulan berakhir di bulan terpilih (untuk grafik tren + ringkasan bulan).
final dashboardRangeProvider = Provider.autoDispose<DateRange>((ref) {
  final m = ref.watch(selectedMonthProvider);
  return DateRange(DateTime(m.year, m.month - 5), DateTime(m.year, m.month + 1));
});

final dashboardTransactionsProvider =
    Provider.autoDispose<AsyncValue<List<MoneyTransaction>>>((ref) {
  return ref.watch(transactionsByRangeProvider(ref.watch(dashboardRangeProvider)));
});

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final txAsync = ref.watch(dashboardTransactionsProvider);
    final balance = ref.watch(balanceProvider);
    final cats = ref.watch(categoryMapProvider);
    final budgets = ref.watch(budgetProgressProvider);
    final user = ref.watch(authStateProvider).valueOrNull;

    final name = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim().split(' ').first
        : 'Pengguna';

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.transactionForm),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Transaksi'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(balanceProvider);
            await ref.read(balanceProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
            children: [
              _Header(name: name, onAvatarTap: () => context.go(AppRoutes.settings)),
              const SizedBox(height: 18),
              const MonthSelector(),
              const SizedBox(height: 16),
              AsyncView<List<MoneyTransaction>>(
                value: txAsync,
                onRetry: () => ref.invalidate(transactionsByRangeProvider),
                data: (all) {
                  final range = DateRange.month(month);
                  final monthTxns =
                      all.where((t) => range.contains(t.date)).toList();
                  final summary = summarize(monthTxns);
                  final slices =
                      buildSlices(byCategory(monthTxns, EntryType.expense), cats);
                  final trend = byMonth(
                      all, DateTime(month.year, month.month - 5), 6);
                  final recent = monthTxns.take(5).toList();
                  final topBudgets =
                      (budgets.valueOrNull ?? const <BudgetProgress>[])
                          .take(3)
                          .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _BalanceCard(
                        total: balance.valueOrNull?.total,
                        income: summary.income,
                        expense: summary.expense,
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Pengeluaran per kategori',
                        child: slices.isEmpty
                            ? const _Hint('Belum ada pengeluaran bulan ini.')
                            : CategoryDonut(
                                slices: slices,
                                centerLabel: 'Total',
                              ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Tren 6 bulan',
                        child: MonthBarChart(data: trend),
                      ),
                      if (topBudgets.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Anggaran bulan ini',
                          trailing: TextButton(
                            onPressed: () => context.go(AppRoutes.budgets),
                            child: const Text('Lihat'),
                          ),
                          child: Column(
                            children: [
                              for (final p in topBudgets)
                                _BudgetRow(progress: p),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Transaksi terbaru',
                        trailing: TextButton(
                          onPressed: () => context.go(AppRoutes.transactions),
                          child: const Text('Semua'),
                        ),
                        child: recent.isEmpty
                            ? const _Hint('Belum ada transaksi bulan ini.')
                            : Column(
                                children: [
                                  for (final t in recent)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: TransactionTile(
                                        transaction: t,
                                        categories: cats,
                                        showDate: true,
                                        onTap: () => context.push(
                                            AppRoutes.transactionForm,
                                            extra: t),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ]
                        .animate(interval: 60.ms)
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: 0.04, curve: Curves.easeOutCubic),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.onAvatarTap});

  final String name;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Fmt.dateLong(DateTime.now()),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text('Halo, $name',
                  style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            ],
          ),
        ),
        InkWell(
          customBorder: const CircleBorder(),
          onTap: onAvatarTap,
          child: CircleAvatar(
            radius: 22,
            backgroundColor: cs.primaryContainer,
            child: Text(
              name.characters.first.toUpperCase(),
              style: tt.titleMedium?.copyWith(
                  color: cs.onPrimaryContainer, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.total,
    required this.income,
    required this.expense,
  });

  final int? total;
  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget pill(IconData icon, String label, int value) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: tt.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85))),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(Fmt.rupiah(value),
                            style: tt.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, Color.lerp(cs.primary, Colors.black, 0.35)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.3),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total saldo',
              style: tt.bodyMedium
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 6),
          if (total == null)
            Text('—',
                style: tt.headlineMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w800))
          else
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: total!.toDouble()),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  Fmt.rupiah(v.round()),
                  style: tt.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              pill(Icons.arrow_downward_rounded, 'Pemasukan', income),
              const SizedBox(width: 10),
              pill(Icons.arrow_upward_rounded, 'Pengeluaran', expense),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: tt.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: cs.onSurfaceVariant)),
    );
  }
}

class _BudgetRow extends ConsumerWidget {
  const _BudgetRow({required this.progress});

  final BudgetProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final cats = ref.watch(categoryMapProvider);
    final look = resolveCategory(cats, progress.budget.categoryId);
    final color = budgetColor(context, progress.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              CategoryAvatar(icon: look.icon, color: look.color, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(look.name,
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Text(Fmt.percent(progress.ratio),
                  style: tt.labelLarge
                      ?.copyWith(color: color, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.ratio.clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              color: color,
              backgroundColor: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
