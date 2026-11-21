import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/form_bits.dart';
import '../../../core/widgets/primary_button.dart';
import '../domain/debt.dart';
import 'debt_providers.dart';

Future<void> showDebtSheet(
  BuildContext context, {
  Debt? initial,
  DebtKind kind = DebtKind.owe,
}) => showFormSheet(context, DebtFormSheet(initial: initial, kind: kind));

class DebtFormSheet extends ConsumerStatefulWidget {
  const DebtFormSheet({super.key, this.initial, required this.kind});

  final Debt? initial;
  final DebtKind kind;

  @override
  ConsumerState<DebtFormSheet> createState() => _DebtFormSheetState();
}

class _DebtFormSheetState extends ConsumerState<DebtFormSheet> {
  final _person = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late DebtKind _kind;
  late DateTime _date;
  DateTime? _due;
  String? _personError;
  String? _amountError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _kind = d?.kind ?? widget.kind;
    _date = d?.date ?? dateOnly(DateTime.now());
    _due = d?.dueDate;
    _person.text = d?.person ?? '';
    _note.text = d?.note ?? '';
    if (d != null) _amount.text = ThousandsFormatter.format('${d.amount}');
  }

  @override
  void dispose() {
    _person.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final person = _person.text.trim();
    final amount = parseAmount(_amount.text);
    final paid = widget.initial?.paid ?? 0;
    setState(() {
      _personError = person.isEmpty
          ? 'Nama wajib diisi'
          : (person.length > 60 ? 'Maksimal 60 karakter' : null);
      _amountError = (amount == null || amount <= 0)
          ? 'Jumlah wajib diisi'
          : (amount < paid
                ? 'Lebih kecil dari yang sudah dibayar (${Fmt.rupiah(paid)})'
                : null);
    });
    if (_personError != null || _amountError != null) return;
    setState(() => _saving = true);
    final a = ref.read(debtActionsProvider);
    final note = _note.text.trim();
    final err = widget.initial == null
        ? await a.add(
            person: person,
            kind: _kind,
            amount: amount!,
            note: note,
            date: _date,
            dueDate: _due,
          )
        : await a.update(
            widget.initial!,
            person: person,
            kind: _kind,
            amount: amount!,
            note: note,
            date: _date,
            dueDate: _due,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      context.showSnack(err, error: true);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SheetBody(
      title: widget.initial == null ? 'Catatan baru' : 'Ubah catatan',
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<DebtKind>(
            showSelectedIcon: false,
            segments: [
              for (final k in DebtKind.values)
                ButtonSegment(value: k, label: Text(k.label)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _person,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: _kind == DebtKind.owe
                ? 'Berutang kepada'
                : 'Yang berutang',
            errorText: _personError,
          ),
        ),
        const SizedBox(height: 16),
        AmountField(
          controller: _amount,
          label: 'Jumlah',
          errorText: _amountError,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Catatan (opsional)',
            hintText: 'Mis. Pinjam untuk servis motor',
          ),
        ),
        DateField(
          label: 'Tanggal',
          value: _date,
          onChanged: (d) => setState(() => _date = dateOnly(d ?? _date)),
        ),
        const SizedBox(height: 16),
        DateField(
          label: 'Jatuh tempo (opsional)',
          value: _due,
          clearable: true,
          onChanged: (d) => setState(() => _due = d),
        ),
        const SizedBox(height: 8),
        Text(
          'Pengingat dikirim pukul 09.00 pada hari jatuh tempo. Catatan ini tidak mengubah saldo dompet.',
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

Future<void> showDebtPaymentSheet(BuildContext context, Debt debt) =>
    showFormSheet(context, _PaymentSheet(debt: debt));

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({required this.debt});

  final Debt debt;

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final _amount = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amount.text = ThousandsFormatter.format('${widget.debt.remaining}');
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save({bool undo = false}) async {
    final v = undo ? widget.debt.paid : parseAmount(_amount.text);
    if (v == null || v <= 0) {
      setState(() => _error = 'Jumlah wajib diisi');
      return;
    }
    if (!undo && v > widget.debt.remaining) {
      setState(
        () => _error = 'Melebihi sisa ${Fmt.rupiah(widget.debt.remaining)}',
      );
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final err = await ref
        .read(debtActionsProvider)
        .pay(widget.debt, undo ? -v : v);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      context.showSnack(err, error: true);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.debt;
    final isOwe = d.kind == DebtKind.owe;
    return SheetBody(
      title: isOwe ? 'Bayar ke ${d.person}' : 'Terima dari ${d.person}',
      children: [
        Text(
          'Sisa ${Fmt.rupiah(d.remaining)} dari ${Fmt.rupiah(d.amount)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        AmountField(
          controller: _amount,
          label: 'Jumlah dibayar',
          errorText: _error,
          autofocus: true,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            label: 'Catat',
            loading: _saving,
            onPressed: () => _save(),
          ),
        ),
        if (d.paid > 0) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _saving ? null : () => _save(undo: true),
              child: Text('Reset pembayaran (${Fmt.rupiah(d.paid)})'),
            ),
          ),
        ],
      ],
    );
  }
}
