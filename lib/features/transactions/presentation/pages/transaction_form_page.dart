import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/entry_type.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/amount_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../categories/presentation/category_style.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../domain/money_transaction.dart';
import '../providers/transaction_providers.dart';

class TransactionFormPage extends ConsumerStatefulWidget {
  const TransactionFormPage({super.key, this.initial});

  final MoneyTransaction? initial;

  @override
  ConsumerState<TransactionFormPage> createState() =>
      _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late EntryType _type;
  late DateTime _date;
  String? _categoryId;
  String? _categoryError;
  bool _saving = false;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _type = i?.type ?? EntryType.expense;
    _date = i?.date ?? dateOnly(DateTime.now());
    if (i != null) {
      _amount.text = ThousandsFormatter.format(i.amount.toString());
      _note.text = i.note;
      _categoryId = i.categoryId;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _save() async {
    final valid = _form.currentState!.validate();
    if (_categoryId == null) {
      setState(() => _categoryError = 'Pilih kategori');
      return;
    }
    if (!valid) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final actions = ref.read(transactionActionsProvider);
    final amount = parseAmount(_amount.text) ?? 0;
    if (amount <= 0) return;
    final note = _note.text.trim();
    final err = _editing
        ? await actions.update(widget.initial!.id,
            type: _type,
            amount: amount,
            categoryId: _categoryId!,
            note: note,
            date: _date)
        : await actions.add(
            type: _type,
            amount: amount,
            categoryId: _categoryId!,
            note: note,
            date: _date);

    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      context.showSnack(err, error: true);
      return;
    }
    context.pop();
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus transaksi?',
      message: 'Transaksi ini akan dihapus permanen.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final err =
        await ref.read(transactionActionsProvider).delete(widget.initial!.id);
    if (!mounted) return;
    if (err != null) {
      context.showSnack(err, error: true);
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fin = context.finance;
    final accent = _type == EntryType.income ? fin.income : fin.expense;
    final cats = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final options = cats.where((c) => c.type == _type).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Ubah transaksi' : 'Tambah transaksi'),
        actions: [
          if (_editing)
            IconButton(
              onPressed: _delete,
              icon: Icon(Icons.delete_outline_rounded, color: cs.error),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: PrimaryButton(
            label: _editing ? 'Simpan perubahan' : 'Simpan transaksi',
            loading: _saving,
            onPressed: _save,
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<EntryType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: EntryType.expense,
                    icon: Icon(Icons.arrow_upward_rounded),
                    label: Text('Pengeluaran'),
                  ),
                  ButtonSegment(
                    value: EntryType.income,
                    icon: Icon(Icons.arrow_downward_rounded),
                    label: Text('Pemasukan'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  final stillValid = cats.any(
                      (c) => c.id == _categoryId && c.type == _type);
                  if (!stillValid) _categoryId = null;
                }),
              ),
            ),
            const SizedBox(height: 24),
            Text('Jumlah',
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandsFormatter(),
              ],
              style: tt.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800, color: accent),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) {
                final n = parseAmount(v ?? '');
                if (n == null || n <= 0) return 'Masukkan jumlah lebih dari 0';
                return null;
              },
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                hintText: '0',
              ),
            ),
            const SizedBox(height: 24),
            Text('Kategori',
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in options)
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 18, color: c.color),
                    label: Text(c.name),
                    selected: _categoryId == c.id,
                    onSelected: (_) => setState(() {
                      _categoryId = c.id;
                      _categoryError = null;
                    }),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Kelola'),
                  onPressed: () => context.push(AppRoutes.categories),
                ),
              ],
            ),
            if (options.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Belum ada kategori ${_type.label.toLowerCase()}. Tambahkan lewat "Kelola".',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            if (_categoryError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_categoryError!,
                    style: tt.bodySmall?.copyWith(color: cs.error)),
              ),
            const SizedBox(height: 24),
            Text('Tanggal',
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.event_rounded),
                ),
                child: Text(Fmt.dateLong(_date), style: tt.bodyLarge),
              ),
            ),
            const SizedBox(height: 24),
            Text('Catatan (opsional)',
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _note,
              maxLength: 200,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Mis. makan siang bersama tim',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
