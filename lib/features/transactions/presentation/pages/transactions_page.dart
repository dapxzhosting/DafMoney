import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_images.dart';
import '../../../../core/models/entry_type.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/animated_amount.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/fab_scroll.dart';
import '../../../../core/widgets/month_selector.dart';
import '../../../categories/domain/category.dart';
import '../../../categories/presentation/category_style.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../wallets/domain/wallet.dart';
import '../../../wallets/presentation/providers/wallet_providers.dart';
import '../../domain/money_transaction.dart';
import '../../domain/transaction_filter.dart';
import '../providers/transaction_providers.dart';
import '../transaction_undo.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/transaction_tile.dart';

sealed class _Row {}

class _HeaderRow extends _Row {
  _HeaderRow(this.date, this.net);
  final DateTime date;
  final int net;
}

class _SummaryRow extends _Row {
  _SummaryRow(this.count, this.income, this.expense);
  final int count;
  final int income;
  final int expense;
}

class _ItemRow extends _Row {
  _ItemRow(this.tx);
  final MoneyTransaction tx;
}

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  EntryType? _filter;
  TxFilter _adv = TxFilter.empty;
  bool _searching = false;
  final _search = TextEditingController();
  final Set<String> _hidden = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _delete(MoneyTransaction t) async {
    // Sembunyikan dulu supaya terasa instan, lalu hapus di server.
    setState(() => _hidden.add(t.id));
    final ok = await deleteWithUndo(
      context,
      ref,
      t,
      onUndone: () {
        if (mounted) setState(() => _hidden.remove(t.id));
      },
    );
    if (!ok && mounted) setState(() => _hidden.remove(t.id));
  }

  List<_Row> _buildRows(List<MoneyTransaction> list, {bool summary = false}) {
    final dayNet = <DateTime, int>{};
    for (final t in list) {
      final k = dateOnly(t.date);
      dayNet[k] =
          (dayNet[k] ?? 0) +
          (t.type == EntryType.income ? t.amount : -t.amount);
    }
    final rows = <_Row>[];
    if (summary) {
      var inc = 0;
      var exp = 0;
      for (final t in list) {
        t.type == EntryType.income ? inc += t.amount : exp += t.amount;
      }
      rows.add(_SummaryRow(list.length, inc, exp));
    }
    DateTime? current;
    for (final t in list) {
      if (current == null || !isSameDay(current, t.date)) {
        current = dateOnly(t.date);
        rows.add(_HeaderRow(current, dayNet[current] ?? 0));
      }
      rows.add(_ItemRow(t));
    }
    return rows;
  }

  Future<void> _openFilter() async {
    final cats = ref.read(categoriesProvider).valueOrNull ?? const <Category>[];
    final wallets = ref.read(walletsProvider).valueOrNull ?? const <Wallet>[];
    final res = await showTxFilterSheet(
      context,
      initial: _adv,
      categories: cats,
      wallets: wallets,
    );
    if (res != null && mounted) setState(() => _adv = res);
  }

  String _amountLabel(TxFilter f) {
    if (f.minAmount != null && f.maxAmount != null) {
      return '${Fmt.rupiahCompact(f.minAmount!)} - ${Fmt.rupiahCompact(f.maxAmount!)}';
    }
    if (f.minAmount != null) return '>= ${Fmt.rupiahCompact(f.minAmount!)}';
    return '<= ${Fmt.rupiahCompact(f.maxAmount!)}';
  }

  Widget _activeFilters(
    Map<String, Category> cats,
    Map<String, Wallet> wallets,
  ) {
    final chips = <Widget>[];

    Widget chip(String label, VoidCallback onDelete) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(label),
        onDeleted: onDelete,
        visualDensity: VisualDensity.compact,
      ),
    );

    for (final id in _adv.categoryIds) {
      chips.add(
        chip(
          resolveCategory(cats, id).name,
          () => setState(
            () => _adv = _adv.copyWith(
              categoryIds: {..._adv.categoryIds}..remove(id),
            ),
          ),
        ),
      );
    }
    for (final id in _adv.walletIds) {
      chips.add(
        chip(
          wallets[id]?.name ?? 'Dompet',
          () => setState(
            () => _adv = _adv.copyWith(
              walletIds: {..._adv.walletIds}..remove(id),
            ),
          ),
        ),
      );
    }
    if (_adv.hasAmount) {
      chips.add(
        chip(
          _amountLabel(_adv),
          () => setState(() => _adv = _adv.copyWith(clearAmount: true)),
        ),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: chips.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    ...chips,
                    ActionChip(
                      avatar: const Icon(Icons.clear_all_rounded, size: 18),
                      label: const Text('Hapus semua'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          setState(() => _adv = TxFilter(scope: _adv.scope)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fin = context.finance;
    final txAsync = _adv.scope == TxScope.month
        ? ref.watch(monthTransactionsProvider)
        : ref.watch(transactionsByRangeProvider(_adv.scope.range));
    final cats = ref.watch(categoryMapProvider);
    final wallets = ref.watch(walletMapProvider);

    return FabScroll(
      builder: (context, fabExtended, onScroll) => Scaffold(
        appBar: AppBar(
          title: _searching
              ? TextField(
                  controller: _search,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Cari catatan atau kategori',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                )
              : const Text('Transaksi'),
          actions: [
            IconButton(
              tooltip: 'Filter',
              onPressed: _openFilter,
              icon: Badge(
                isLabelVisible: _adv.activeCount > 0,
                label: Text('${_adv.activeCount}'),
                child: const Icon(Icons.tune_rounded),
              ),
            ),
            IconButton(
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) _search.clear();
              }),
              icon: Icon(
                _searching ? Icons.close_rounded : Icons.search_rounded,
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          isExtended: fabExtended,
          onPressed: () => context.push(AppRoutes.transactionForm),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Transaksi'),
        ),
        body: NotificationListener<ScrollNotification>(
          onNotification: onScroll,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _adv.scope == TxScope.month
                      ? const MonthSelector(key: ValueKey('month'))
                      : _ScopeBanner(
                          key: const ValueKey('scope'),
                          scope: _adv.scope,
                          onReset: () => setState(
                            () => _adv = _adv.copyWith(scope: TxScope.month),
                          ),
                        ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    for (final f in <EntryType?>[
                      null,
                      EntryType.expense,
                      EntryType.income,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f == null ? 'Semua' : f.label),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ),
                  ],
                ),
              ),
              _activeFilters(cats, wallets),
              const SizedBox(height: 8),
              Expanded(
                child: AsyncView<List<MoneyTransaction>>(
                  value: txAsync,
                  data: (all) {
                    final q = _search.text.trim().toLowerCase();
                    final qDigits = q.replaceAll('.', '').replaceAll(',', '');
                    final numericQuery =
                        qDigits.isNotEmpty && int.tryParse(qDigits) != null;
                    final list = all.where((t) {
                      if (_hidden.contains(t.id)) return false;
                      if (_filter != null && t.type != _filter) return false;
                      if (!_adv.matches(t)) return false;
                      if (q.isEmpty) return true;
                      final name = resolveCategory(cats, t.categoryId).name;
                      return t.note.toLowerCase().contains(q) ||
                          name.toLowerCase().contains(q) ||
                          (numericQuery &&
                              t.amount.toString().contains(qDigits));
                    }).toList();
                    final filtering =
                        _filter != null || q.isNotEmpty || _adv.isActive;

                    if (list.isEmpty) {
                      return EmptyState(
                        image: AppImages.belumAdaTransaksi,
                        icon: Icons.receipt_long_rounded,
                        title: all.isEmpty
                            ? 'Belum ada transaksi'
                            : 'Tidak ada hasil',
                        message: all.isEmpty
                            ? 'Catat pemasukan atau pengeluaran pertama Anda di bulan ini.'
                            : 'Coba ubah filter, kata kunci, atau nominal pencarian.',
                        actionLabel: all.isEmpty ? 'Tambah transaksi' : null,
                        onAction: () => context.push(AppRoutes.transactionForm),
                      );
                    }

                    final rows = _buildRows(list, summary: filtering);
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final row = rows[i];
                        if (row is _SummaryRow) {
                          return _ResultSummary(row: row);
                        }
                        if (row is _HeaderRow) {
                          return Padding(
                            padding: EdgeInsets.only(
                              top: i == 0 ? 0 : 14,
                              bottom: 8,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    Fmt.dayHeader(row.date),
                                    style: tt.labelLarge?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${row.net >= 0 ? '+' : '-'}${Fmt.rupiah(row.net.abs())}',
                                  style: tt.labelMedium?.copyWith(
                                    color: row.net >= 0
                                        ? fin.income
                                        : fin.expense,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        final t = (row as _ItemRow).tx;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Dismissible(
                            key: ValueKey(t.id),
                            direction: DismissDirection.horizontal,
                            // Geser ke kanan: gandakan.
                            background: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 22),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.copy_rounded,
                                    color: cs.onPrimaryContainer,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Gandakan',
                                    style: tt.labelLarge?.copyWith(
                                      color: cs.onPrimaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Geser ke kiri: hapus (bisa dibatalkan).
                            secondaryBackground: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 22),
                              decoration: BoxDecoration(
                                color: cs.error,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                Icons.delete_rounded,
                                color: cs.onError,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                // Jangan tunggu: kartu langsung kembali ke posisi.
                                unawaited(duplicateWithUndo(context, ref, t));
                                return false;
                              }
                              HapticFeedback.mediumImpact();
                              return true;
                            },
                            onDismissed: (_) => _delete(t),
                            child: TransactionTile(
                              transaction: t,
                              categories: cats,
                              wallets: wallets,
                              onTap: () => context.push(
                                AppRoutes.transactionForm,
                                extra: t,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Banner saat pencarian lintas bulan (menggantikan pemilih bulan).
class _ScopeBanner extends StatelessWidget {
  const _ScopeBanner({super.key, required this.scope, required this.onReset});

  final TxScope scope;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final text = switch (scope) {
      TxScope.month => 'Bulan terpilih',
      TxScope.last3 => '3 bulan terakhir',
      TxScope.last12 => '12 bulan terakhir',
      TxScope.all => 'Semua waktu',
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.travel_explore_rounded, color: cs.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mencari di: $text',
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSecondaryContainer,
              ),
            ),
          ),
          TextButton(onPressed: onReset, child: const Text('Kembali ke bulan')),
        ],
      ),
    );
  }
}

/// Ringkasan hasil saat ada pencarian / filter aktif.
class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.row});

  final _SummaryRow row;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fin = context.finance;

    Widget amount(String sign, int v, Color c) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(sign, style: tt.labelMedium?.copyWith(color: c)),
        AnimatedAmount(
          value: v,
          maskable: false,
          duration: const Duration(milliseconds: 600),
          style: tt.labelMedium?.copyWith(
            color: c,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );

    return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.filter_alt_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                '${row.count} transaksi',
                style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (row.income > 0) amount('+', row.income, fin.income),
              if (row.income > 0 && row.expense > 0) const SizedBox(width: 10),
              if (row.expense > 0) amount('-', row.expense, fin.expense),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 250.ms)
        .slideY(begin: -0.3, curve: Curves.easeOutCubic);
  }
}
