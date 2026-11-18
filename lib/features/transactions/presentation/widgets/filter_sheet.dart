import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/entry_type.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/amount_formatter.dart';
import '../../../categories/domain/category.dart';
import '../../../categories/presentation/category_style.dart';
import '../../../wallets/domain/wallet.dart';
import '../../domain/transaction_filter.dart';

Future<TxFilter?> showTxFilterSheet(
  BuildContext context, {
  required TxFilter initial,
  required List<Category> categories,
  required List<Wallet> wallets,
}) {
  return showModalBottomSheet<TxFilter>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (_) => _FilterSheet(
      initial: initial,
      categories: categories,
      wallets: wallets,
    ),
  );
}

class _AmountPreset {
  const _AmountPreset(this.label, this.min, this.max);

  final String label;
  final int? min;
  final int? max;
}

const _presets = [
  _AmountPreset('< 50 rb', null, 49999),
  _AmountPreset('50 - 200 rb', 50000, 200000),
  _AmountPreset('200 rb - 1 jt', 200000, 1000000),
  _AmountPreset('> 1 jt', 1000001, null),
];

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.categories,
    required this.wallets,
  });

  final TxFilter initial;
  final List<Category> categories;
  final List<Wallet> wallets;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<String> _cats;
  late Set<String> _wallets;
  late TxScope _scope;
  late final TextEditingController _min;
  late final TextEditingController _max;

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    _cats = {...f.categoryIds};
    _wallets = {...f.walletIds};
    _scope = f.scope;
    _min = TextEditingController(
      text: f.minAmount == null
          ? ''
          : ThousandsFormatter.format(f.minAmount.toString()),
    );
    _max = TextEditingController(
      text: f.maxAmount == null
          ? ''
          : ThousandsFormatter.format(f.maxAmount.toString()),
    );
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _applyPreset(_AmountPreset p) {
    HapticFeedback.selectionClick();
    setState(() {
      _min.text = p.min == null ? '' : ThousandsFormatter.format('${p.min}');
      _max.text = p.max == null ? '' : ThousandsFormatter.format('${p.max}');
    });
  }

  TxFilter _build() {
    final minV = parseAmount(_min.text);
    final maxV = parseAmount(_max.text);
    return TxFilter(
      categoryIds: _cats,
      walletIds: _wallets,
      minAmount: minV,
      maxAmount: maxV,
      scope: _scope,
    );
  }

  void _toggle(Set<String> set, String id) {
    HapticFeedback.selectionClick();
    setState(() => set.contains(id) ? set.remove(id) : set.add(id));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs),
      child: Text(
        t,
        style: tt.labelLarge?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final expense = widget.categories
        .where((c) => c.type == EntryType.expense)
        .toList();
    final income = widget.categories
        .where((c) => c.type == EntryType.income)
        .toList();

    Widget catChips(List<Category> list) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in list)
          FilterChip(
            avatar: Icon(c.icon, size: 18, color: c.color),
            label: Text(c.name),
            selected: _cats.contains(c.id),
            onSelected: (_) => _toggle(_cats, c.id),
          ),
      ],
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  0,
                  Gap.page,
                  Gap.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter transaksi',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: Gap.md),
                    label('Jangkauan pencarian'),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<TxScope>(
                        showSelectedIcon: false,
                        segments: [
                          for (final s in TxScope.values)
                            ButtonSegment(
                              value: s,
                              label: Text(
                                s == TxScope.month ? 'Bulan' : s.label,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                        selected: {_scope},
                        onSelectionChanged: (s) =>
                            setState(() => _scope = s.first),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _scope == TxScope.month
                          ? 'Memakai bulan yang dipilih di halaman Transaksi.'
                          : 'Mencari lintas bulan. Pemilih bulan dinonaktifkan.',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: Gap.md),
                    label('Nominal'),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _min,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              ThousandsFormatter(),
                            ],
                            decoration: const InputDecoration(
                              prefixText: 'Rp ',
                              hintText: 'Min',
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('-'),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _max,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              ThousandsFormatter(),
                            ],
                            decoration: const InputDecoration(
                              prefixText: 'Rp ',
                              hintText: 'Maks',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.xs),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final p in _presets)
                          ActionChip(
                            label: Text(p.label),
                            onPressed: () => _applyPreset(p),
                          ),
                      ],
                    ),
                    if (expense.isNotEmpty) ...[
                      const SizedBox(height: Gap.md),
                      label('Kategori pengeluaran'),
                      catChips(expense),
                    ],
                    if (income.isNotEmpty) ...[
                      const SizedBox(height: Gap.md),
                      label('Kategori pemasukan'),
                      catChips(income),
                    ],
                    if (widget.wallets.isNotEmpty) ...[
                      const SizedBox(height: Gap.md),
                      label('Dompet'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final w in widget.wallets)
                            FilterChip(
                              label: Text(w.name),
                              selected: _wallets.contains(w.id),
                              onSelected: (_) => _toggle(_wallets, w.id),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.xs,
                Gap.page,
                Gap.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(TxFilter.empty),
                      child: const Text('Atur ulang'),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_build()),
                      child: const Text('Terapkan'),
                    ),
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
