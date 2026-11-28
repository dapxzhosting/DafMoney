import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/entry_type.dart';
import '../../../core/utils/amount_formatter.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/form_bits.dart';
import '../../../core/widgets/primary_button.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/providers/category_providers.dart';
import '../../wallets/domain/wallet.dart';
import '../../wallets/presentation/providers/wallet_providers.dart';
import '../domain/recurring_entry.dart';
import 'recurring_providers.dart';

Future<void> showRecurringSheet(
  BuildContext context, {
  RecurringEntry? initial,
}) => showFormSheet(context, RecurringFormSheet(initial: initial));

class RecurringFormSheet extends ConsumerStatefulWidget {
  const RecurringFormSheet({super.key, this.initial});

  final RecurringEntry? initial;

  @override
  ConsumerState<RecurringFormSheet> createState() => _RecurringFormSheetState();
}

class _RecurringFormSheetState extends ConsumerState<RecurringFormSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late EntryType _type;
  late Frequency _frequency;
  late DateTime _start;
  String? _categoryId;
  String? _walletId;
  String? _amountError;
  String? _categoryError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _type = r?.type ?? EntryType.expense;
    _frequency = r?.frequency ?? Frequency.monthly;
    _start = r?.startDate ?? dateOnly(DateTime.now());
    _categoryId = r?.categoryId;
    _walletId = r?.walletId;
    _note.text = r?.note ?? '';
    if (r != null) {
      _amount.text = ThousandsFormatter.format(r.amount.toString());
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    setState(() {
      _amountError = (amount == null || amount <= 0)
          ? 'Nominal wajib diisi'
          : null;
      _categoryError = _categoryId == null ? 'Pilih kategori' : null;
    });
    if (_amountError != null || _categoryError != null) return;
    setState(() => _saving = true);
    final actions = ref.read(recurringActionsProvider);
    final note = _note.text.trim();
    final err = widget.initial == null
        ? await actions.add(
            type: _type,
            amount: amount!,
            categoryId: _categoryId!,
            note: note,
            frequency: _frequency,
            startDate: _start,
            walletId: _walletId,
          )
        : await actions.update(
            widget.initial!,
            type: _type,
            amount: amount!,
            categoryId: _categoryId!,
            note: note,
            frequency: _frequency,
            startDate: _start,
            walletId: _walletId,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    context.closeSheetWithResult(err);
  }

  @override
  Widget build(BuildContext context) {
    final cats =
        (ref.watch(categoriesProvider).valueOrNull ?? const <Category>[])
            .where((c) => c.type == _type)
            .toList();
    final wallets = ref.watch(walletsProvider).valueOrNull ?? const <Wallet>[];
    final validCat = cats.any((c) => c.id == _categoryId) ? _categoryId : null;
    final validWallet = wallets.any((w) => w.id == _walletId)
        ? _walletId
        : null;

    return SheetBody(
      title: widget.initial == null
          ? 'Transaksi berulang baru'
          : 'Ubah transaksi berulang',
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<EntryType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: EntryType.expense,
                label: Text('Pengeluaran'),
              ),
              ButtonSegment(value: EntryType.income, label: Text('Pemasukan')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _categoryId = null;
            }),
          ),
        ),
        const SizedBox(height: 16),
        AmountField(
          controller: _amount,
          errorText: _amountError,
          autofocus: widget.initial == null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('cat-${_type.name}'),
          initialValue: validCat,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Kategori',
            errorText: _categoryError,
          ),
          items: [
            for (final c in cats)
              DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: (v) => setState(() => _categoryId = v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(
          initialValue: validWallet,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Dompet (opsional)'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Tanpa dompet'),
            ),
            for (final w in wallets)
              DropdownMenuItem<String?>(value: w.id, child: Text(w.name)),
          ],
          onChanged: (v) => setState(() => _walletId = v),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Catatan (opsional)',
            hintText: 'Mis. Gaji bulanan, Netflix, Cicilan motor',
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Frequency>(
          initialValue: _frequency,
          decoration: const InputDecoration(labelText: 'Pengulangan'),
          items: [
            for (final f in Frequency.values)
              DropdownMenuItem(value: f, child: Text(f.label)),
          ],
          onChanged: (v) => setState(() => _frequency = v ?? _frequency),
        ),
        const SizedBox(height: 16),
        DateField(
          label: 'Mulai tanggal',
          value: _start,
          onChanged: (d) => setState(() => _start = dateOnly(d ?? _start)),
        ),
        const SizedBox(height: 8),
        Text(
          'Jika tanggal mulai sudah lewat, transaksi yang terlewat langsung dicatat (maksimal 31 kali).',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            label: 'Simpan',
            loading: _saving,
            onPressed: _save,
          ),
        ),
      ],
    );
  }
}
