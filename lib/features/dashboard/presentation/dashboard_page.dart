import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/models/entry_type.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/privacy_providers.dart';
import '../../../core/providers/session_providers.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/widget_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/animated_amount.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/category_avatar.dart';
import '../../../core/widgets/charts/category_donut.dart';
import '../../../core/widgets/charts/month_bar_chart.dart';
import '../../../core/widgets/month_selector.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/speed_dial_fab.dart';
import '../../budgets/domain/budget.dart';
import '../../budgets/presentation/pages/budgets_page.dart';
import '../../budgets/presentation/providers/budget_providers.dart';
import '../../categories/presentation/category_style.dart';
import '../../categories/presentation/providers/category_providers.dart';
import '../../challenge/presentation/challenge_card.dart';
import '../../export/domain/export_builder.dart';
import '../../export/domain/export_report.dart';
import '../../insights/domain/insight_engine.dart';
import '../../insights/presentation/insight_share_page.dart';
import '../../insights/presentation/insights_carousel.dart';
import '../../insights/presentation/month_story_page.dart';
import '../../reports/domain/report_calculator.dart';
import '../../settings/presentation/providers/settings_providers.dart';
import '../../transactions/domain/money_transaction.dart';
import '../../transactions/presentation/providers/transaction_providers.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';
import '../../wallets/domain/wallet.dart';
import '../../wallets/presentation/providers/wallet_providers.dart';
import '../../wallets/presentation/wallet_style.dart';
import '../../../core/widgets/motion.dart';

final dashboardRangeProvider = Provider.autoDispose<DateRange>((ref) {
  final m = ref.watch(selectedMonthProvider);
  return DateRange(
    DateTime(m.year, m.month - 5),
    DateTime(m.year, m.month + 1),
  );
});

final dashboardTransactionsProvider =
    Provider.autoDispose<AsyncValue<List<MoneyTransaction>>>((ref) {
      return ref.watch(
        transactionsByRangeProvider(ref.watch(dashboardRangeProvider)),
      );
    });

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _fabExtended = true;
  bool _dialOpen = false;
  bool _compact = false;

  static const _compactThreshold = 250.0;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final pixels = n.metrics.pixels;
    final compact = pixels > _compactThreshold;
    if (compact != _compact) setState(() => _compact = compact);

    if (n is ScrollUpdateNotification) {
      final delta = n.scrollDelta ?? 0;
      final atTop = pixels < 48;
      if ((atTop || delta < -1) && !_fabExtended) {
        setState(() => _fabExtended = true);
      } else if (!atTop && delta > 1 && _fabExtended) {
        setState(() => _fabExtended = false);
      }
    }
    return false;
  }

  void _closeDial() {
    if (_dialOpen) setState(() => _dialOpen = false);
  }

  void _addTransaction(EntryType type) {
    setState(() => _dialOpen = false);
    context.push('${AppRoutes.transactionForm}?type=${type.name}');
  }

  void _openStory(List<MoneyTransaction> monthTxns) {
    final month = ref.read(selectedMonthProvider);
    final report = buildExportReport(
      scope: ExportScope.month,
      range: DateRange.month(month),
      txns: monthTxns,
      cats: ref.read(categoryMapProvider),
      wallets: ref.read(walletMapProvider),
    );
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MonthStoryPage.route(report));
  }

  void _shareInsight(Insight insight, DateTime month) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => InsightSharePage(
          insight: insight,
          periodLabel: Fmt.monthYear(month),
        ),
      ),
    );
  }

  List<double> _sparkline(List<MoneyTransaction> all) {
    final today = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(today.year, today.month, today.day - (6 - i)),
    );
    final net = <DateTime, int>{for (final d in days) d: 0};
    for (final t in all) {
      final d = DateTime(t.date.year, t.date.month, t.date.day);
      if (!net.containsKey(d)) continue;
      net[d] = net[d]! + (t.type == EntryType.income ? t.amount : -t.amount);
    }
    if (net.values.every((v) => v == 0)) return const <double>[];
    var running = 0;
    return [for (final d in days) (running += net[d]!).toDouble()];
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedMonthProvider);
    final txAsync = ref.watch(dashboardTransactionsProvider);
    final balance = ref.watch(balanceProvider);
    final cats = ref.watch(categoryMapProvider);
    final budgets = ref.watch(budgetProgressProvider);
    final user = ref.watch(authStateProvider).valueOrNull;

    final allTxns = txAsync.valueOrNull;
    final monthRange = DateRange.month(month);
    final monthSummary = allTxns == null
        ? const PeriodSummary(0, 0)
        : summarize(allTxns.where((t) => monthRange.contains(t.date)).toList());

    final profile = ref.watch(userProfileProvider).valueOrNull;
    final int initialBalance =
        (profile?.initialBalance ?? 0).toInt() +
        ref.watch(walletsInitialSumProvider).toInt();
    final wallets = ref.watch(walletMapProvider);
    final fullName = (profile?.name.trim().isNotEmpty ?? false)
        ? profile!.name.trim()
        : (user?.displayName?.trim() ?? '');
    final name = fullName.isNotEmpty ? fullName.split(' ').first : 'Pengguna';

    final totalBalance = (balance.valueOrNull?.total ?? 0) + initialBalance;
    final budgetList = budgets.valueOrNull ?? const <BudgetProgress>[];
    final monthTxnsAll = allTxns == null
        ? const <MoneyTransaction>[]
        : allTxns.where((t) => monthRange.contains(t.date)).toList();
    final insights = allTxns == null
        ? const <Insight>[]
        : buildInsights(
            all: allTxns,
            month: month,
            cats: cats,
            budgets: budgetList,
          );
    final remainingBudget = budgetList.fold<int>(
      0,
      (sum, b) => sum + (b.remaining > 0 ? b.remaining : 0),
    );

    if (balance.hasValue && budgets.hasValue) {
      WidgetService.updateWidgetData(
        balance: totalBalance,
        remainingBudget: remainingBudget,
      );
    }

    return PopScope(
      canPop: !_dialOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeDial();
      },
      child: Scaffold(
        floatingActionButton: SpeedDialFab(
          open: _dialOpen,
          extended: _fabExtended,
          onToggle: () => setState(() => _dialOpen = !_dialOpen),
          actions: [
            SpeedDialAction(
              icon: Icons.arrow_downward_rounded,
              label: 'Pemasukan',
              color: context.finance.income,
              onTap: () => _addTransaction(EntryType.income),
            ),
            SpeedDialAction(
              icon: Icons.arrow_upward_rounded,
              label: 'Pengeluaran',
              color: context.finance.expense,
              onTap: () => _addTransaction(EntryType.expense),
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(txTotalsByWalletProvider);
                  await ref.read(txTotalsByWalletProvider.future);
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      Gap.page,
                      Gap.sm,
                      Gap.page,
                      110,
                    ),
                    children: [
                      _Header(
                        name: name,
                        onAvatarTap: () => context.push(AppRoutes.settings),
                      ),
                      const SizedBox(height: Gap.md),
                      const MonthSelector(),
                      const SizedBox(height: Gap.md),
                      _BalanceCard(
                        total: balance.valueOrNull == null
                            ? null
                            : balance.valueOrNull!.total + initialBalance,
                        income: monthSummary.income,
                        expense: monthSummary.expense,
                        sparkline: allTxns == null
                            ? const <double>[]
                            : _sparkline(allTxns),
                        error: balance.hasError
                            ? errorText(balance.error!)
                            : null,
                      ),
                      const SizedBox(height: Gap.md),
                      const _QuickActions(),
                      const SizedBox(height: Gap.lg),
                      if (monthTxnsAll.isNotEmpty) ...[
                        InsightsCarousel(
                          insights: insights,
                          storyTitle: 'Kilas ${Fmt.monthYear(month)}',
                          onOpenStory: () => _openStory(monthTxnsAll),
                          onShareInsight: (i) => _shareInsight(i, month),
                        ),
                        const SizedBox(height: Gap.lg),
                      ],
                      const _WalletStrip(),
                      const SizedBox(height: Gap.lg),
                      const ChallengeCard(),
                      const SizedBox(height: Gap.lg),
                      AsyncView<List<MoneyTransaction>>(
                        value: txAsync,
                        loading: const SkeletonList(
                          padding: EdgeInsets.zero,
                          count: 3,
                        ),
                        onRetry: () =>
                            ref.invalidate(transactionsByRangeProvider),
                        data: (all) {
                          final range = DateRange.month(month);
                          final monthTxns = all
                              .where((t) => range.contains(t.date))
                              .toList();
                          final slices = buildSlices(
                            byCategory(monthTxns, EntryType.expense),
                            cats,
                          );
                          final trend = byMonth(
                            all,
                            DateTime(month.year, month.month - 5),
                            6,
                          );
                          final recent = monthTxns.take(5).toList();
                          final topBudgets = budgetList.take(3).toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:
                                <Widget>[
                                      if (topBudgets.isNotEmpty) ...[
                                        _SectionCard(
                                          title: 'Anggaran bulan ini',
                                          actionLabel: 'Lihat',
                                          onAction: () =>
                                              context.go(AppRoutes.budgets),
                                          child: Column(
                                            children: [
                                              for (final p in topBudgets)
                                                _BudgetRow(progress: p),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: Gap.lg),
                                      ],
                                      _SectionCard(
                                        title: 'Transaksi terbaru',
                                        actionLabel: 'Semua',
                                        onAction: () =>
                                            context.go(AppRoutes.transactions),
                                        child: recent.isEmpty
                                            ? const _Hint(
                                                'Belum ada transaksi bulan ini.',
                                              )
                                            : Column(
                                                children: [
                                                  for (final t in recent)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            bottom: Gap.xs,
                                                          ),
                                                      child: TransactionTile(
                                                        transaction: t,
                                                        categories: cats,
                                                        wallets: wallets,
                                                        showDate: true,
                                                        onTap: () => context.push(
                                                          AppRoutes
                                                              .transactionForm,
                                                          extra: t,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                      ),
                                      const SizedBox(height: Gap.lg),
                                      _SectionCard(
                                        title: 'Pengeluaran per kategori',
                                        child: slices.isEmpty
                                            ? const _Hint(
                                                'Belum ada pengeluaran bulan ini.',
                                              )
                                            : CategoryDonut(
                                                slices: slices,
                                                centerLabel: 'Total',
                                              ),
                                      ),
                                      const SizedBox(height: Gap.lg),
                                      _SectionCard(
                                        title: 'Tren 6 bulan',
                                        child: MonthBarChart(data: trend),
                                      ),
                                    ]
                                    .animate(interval: 60.ms)
                                    .fadeIn(duration: 350.ms)
                                    .slideY(
                                      begin: 0.04,
                                      curve: Curves.easeOutCubic,
                                    ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _CompactBar(
                  visible: _compact,
                  name: name,
                  total: balance.valueOrNull == null ? null : totalBalance,
                  onAvatarTap: () => context.push(AppRoutes.settings),
                ),
              ),
              Positioned.fill(
                child: _Scrim(visible: _dialOpen, onTap: _closeDial),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim({required this.visible, required this.onTap});

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: visible
            ? GestureDetector(
                key: const ValueKey('scrim'),
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: ColoredBox(
                      color: cs.scrim.withValues(alpha: 0.35),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(key: ValueKey('no-scrim')),
      ),
    );
  }
}

class _CompactBar extends ConsumerWidget {
  const _CompactBar({
    required this.visible,
    required this.name,
    required this.total,
    required this.onAvatarTap,
  });

  final bool visible;
  final String name;
  final int? total;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hidden = ref.watch(hideBalanceProvider);

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, -1),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: visible ? 1 : 0,
          child: Material(
            color: cs.surface,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.25),
            surfaceTintColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.page,
                vertical: Gap.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total saldo',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        if (total == null)
                          const SkeletonBox(width: 120, height: 20, radius: 6)
                        else
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: AnimatedAmount(
                              value: total!,
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: hidden ? 'Tampilkan saldo' : 'Sembunyikan saldo',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref.read(hideBalanceProvider.notifier).toggle();
                    },
                    icon: Icon(
                      hidden
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                    ),
                  ),
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onAvatarTap,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        name.characters.first.toUpperCase(),
                        style: tt.labelLarge?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fin = context.finance;

    Widget item(IconData icon, String label, Color color, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        item(
          Icons.arrow_downward_rounded,
          'Pemasukan',
          fin.income,
          () => context.push('${AppRoutes.transactionForm}?type=income'),
        ),
        item(
          Icons.arrow_upward_rounded,
          'Pengeluaran',
          fin.expense,
          () => context.push('${AppRoutes.transactionForm}?type=expense'),
        ),
        item(
          Icons.account_balance_wallet_rounded,
          'Dompet',
          cs.primary,
          () => context.go(AppRoutes.wallets),
        ),
        item(
          Icons.insert_chart_rounded,
          'Laporan',
          cs.tertiary,
          () => context.go(AppRoutes.reports),
        ),
      ],
    );
  }
}

class _WalletStrip extends ConsumerWidget {
  const _WalletStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fin = context.finance;
    final wallets = ref.watch(walletsProvider).valueOrNull ?? const <Wallet>[];
    final totals =
        ref.watch(walletTotalsProvider).valueOrNull ??
        const <String, Balance>{};

    Widget addCard() => InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.go(AppRoutes.wallets),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(Gap.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: cs.primary),
            const SizedBox(height: 4),
            SwapText(
              wallets.isEmpty ? 'Tambah dompet' : 'Kelola',
              style: tt.labelMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );

    Widget walletCard(Wallet w) {
      final bal = w.initialBalance + (totals[w.id]?.total ?? 0);
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go(AppRoutes.wallets),
        child: Container(
          width: 168,
          padding: const EdgeInsets.all(Gap.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                w.color.withValues(alpha: 0.22),
                w.color.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: w.color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CategoryAvatar(icon: w.icon, color: w.color, size: 32),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      w.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedAmount(
                  value: bal,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: bal < 0 ? fin.expense : cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Dompet',
          actionLabel: 'Kelola',
          onAction: () => context.go(AppRoutes.wallets),
        ),
        const SizedBox(height: Gap.xs),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: wallets.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: Gap.sm),
            itemBuilder: (_, i) =>
                i < wallets.length ? walletCard(wallets[i]) : addCard(),
          ),
        ),
      ],
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
              Text(
                Fmt.dateLong(DateTime.now()),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                'Halo, $name',
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
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
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({
    required this.total,
    required this.income,
    required this.expense,
    this.sparkline = const <double>[],
    this.error,
  });

  final int? total;
  final int income;
  final int expense;
  final List<double> sparkline;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hidden = ref.watch(hideBalanceProvider);

    Widget pill(IconData icon, String label, int value) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(Gap.sm),
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
            const SizedBox(width: Gap.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedAmount(
                      value: value,
                      style: tt.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -40,
              child: _Glow(size: 200, alpha: 0.16),
            ),
            Positioned(
              bottom: -70,
              left: -50,
              child: _Glow(size: 180, alpha: 0.10),
            ),
            Positioned(top: 20, right: 56, child: _Ring(size: 70)),
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total saldo',
                          style: tt.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: hidden
                            ? 'Tampilkan saldo'
                            : 'Sembunyikan saldo',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          ref.read(hideBalanceProvider.notifier).toggle();
                        },
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: Icon(
                            hidden
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            key: ValueKey(hidden),
                            size: 20,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (total == null)
                    SkeletonBox(
                      width: 190,
                      height: 36,
                      radius: 12,
                      color: Colors.white.withValues(alpha: 0.22),
                    )
                  else
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AnimatedAmount(
                        value: total!,
                        style: tt.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Saldo gagal dimuat: $error',
                        style: tt.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  if (sparkline.length >= 2) ...[
                    const SizedBox(height: Gap.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: CustomPaint(
                              painter: _SparklinePainter(sparkline),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                        const SizedBox(width: Gap.xs),
                        Text(
                          '7 hari',
                          style: tt.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: Gap.md),
                  Row(
                    children: [
                      pill(Icons.arrow_downward_rounded, 'Pemasukan', income),
                      const SizedBox(width: Gap.xs),
                      pill(Icons.arrow_upward_rounded, 'Pengeluaran', expense),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          Colors.white.withValues(alpha: alpha),
          Colors.white.withValues(alpha: 0),
        ],
      ),
    ),
  );
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.12),
        width: 1.5,
      ),
    ),
  );
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final dx = size.width / (values.length - 1);

    Offset pt(int i) => Offset(
      dx * i,
      size.height - ((values[i] - minV) / range) * (size.height - 6) - 3,
    );

    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      final p0 = pt(i - 1);
      final p1 = pt(i);
      final mid = (p0.dx + p1.dx) / 2;
      line.cubicTo(mid, p0.dy, mid, p1.dy, p1.dx, p1.dy);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      pt(values.length - 1),
      3.5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: title,
              actionLabel: actionLabel,
              onAction: onAction,
            ),
            const SizedBox(height: Gap.sm),
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
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: cs.onSurfaceVariant),
      ),
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
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Column(
        children: [
          Row(
            children: [
              CategoryAvatar(icon: look.icon, color: look.color, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  look.name,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                Fmt.percent(progress.ratio),
                style: tt.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: progress.ratio.clamp(0.0, 1.0).toDouble(),
              ),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                color: color,
                backgroundColor: cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
