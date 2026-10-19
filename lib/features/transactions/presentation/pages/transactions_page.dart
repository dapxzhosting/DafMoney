import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/entry_type.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/month_selector.dart';
import '../../../categories/presentation/category_style.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../domain/money_transaction.dart';
import '../providers/transaction_providers.dart';
import '../widgets/transaction_tile.dart';

sealed class _Row {}

class _HeaderRow extends _Row {
  _HeaderRow(this.date, this.net);
  final DateTime date;
  final int net;
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
  bool _searching = false;
  final _search = TextEditingController();
  final Set<String> _hidden = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _delete(MoneyTransaction t) async {
    setState(() => _hidden.add(t.id));
    final err = await ref.read(transactionActionsProvider).delete(t.id);
    if (!mounted) return;
    if (err != null) {
      setState(() => _hidden.remove(t.id));
      context.showSnack(err, error: true);
    } else {
      context.showSnack('Transaksi dihapus.');
    }
  }

  List<_Row> _buildRows(List<MoneyTransaction> list) {
    final dayNet = <DateTime, int>{};
    for (final t in list) {
      final k = dateOnly(t.date);
      dayNet[k] = (dayNet[k] ?? 0) +
          (t.type == EntryType.income ? t.amount : -t.amount);
    }
    final rows = <_Row>[];
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fin = context.finance;
    final txAsync = ref.watch(monthTransactionsProvider);
    final cats = ref.watch(categoryMapProvider);

    return Scaffold(
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
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _search.clear();
            }),
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.transactionForm),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Transaksi'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: MonthSelector(),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final f in <EntryType?>[null, EntryType.expense, EntryType.income])
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
          const SizedBox(height: 8),
          Expanded(
            child: AsyncView<List<MoneyTransaction>>(
              value: txAsync,
              data: (all) {
                final q = _search.text.trim().toLowerCase();
                final list = all.where((t) {
                  if (_hidden.contains(t.id)) return false;
                  if (_filter != null && t.type != _filter) return false;
                  if (q.isEmpty) return true;
                  final name = resolveCategory(cats, t.categoryId).name;
                  return t.note.toLowerCase().contains(q) ||
                      name.toLowerCase().contains(q);
                }).toList();

                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: all.isEmpty
                        ? 'Belum ada transaksi'
                        : 'Tidak ada hasil',
                    message: all.isEmpty
                        ? 'Catat pemasukan atau pengeluaran pertama Anda di bulan ini.'
                        : 'Coba ubah filter atau kata kunci pencarian.',
                    actionLabel: all.isEmpty ? 'Tambah transaksi' : null,
                    onAction: () => context.push(AppRoutes.transactionForm),
                  );
                }

                final rows = _buildRows(list);
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final row = rows[i];
                    if (row is _HeaderRow) {
                      return Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 14, bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                Fmt.dayHeader(row.date),
                                style: tt.labelLarge?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              '${row.net >= 0 ? '+' : '-'}${Fmt.rupiah(row.net.abs())}',
                              style: tt.labelMedium?.copyWith(
                                color: row.net >= 0 ? fin.income : fin.expense,
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
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 22),
                          decoration: BoxDecoration(
                            color: cs.error,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(Icons.delete_rounded, color: cs.onError),
                        ),
                        confirmDismiss: (_) => confirmDialog(
                          context,
                          title: 'Hapus transaksi?',
                          message: 'Transaksi ini akan dihapus permanen.',
                          confirmLabel: 'Hapus',
                          destructive: true,
                        ),
                        onDismissed: (_) => _delete(t),
                        child: TransactionTile(
                          transaction: t,
                          categories: cats,
                          onTap: () => context.push(
                              AppRoutes.transactionForm,
                              extra: t),
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
    );
  }
}
