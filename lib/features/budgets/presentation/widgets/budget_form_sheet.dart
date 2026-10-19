import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/amount_formatter.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../categories/domain/category.dart';
import '../../../categories/presentation/category_style.dart';
import '../../domain/budget.dart';
import '../providers/budget_providers.dart';

Future<void> showBudgetSheet(
  BuildContext context, {
  required DateTime month,
  required List<Category> choices,
  Budget? existing,
  Category? existingCategory,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => BudgetFormSheet(
      month: month,
      choices: choices,
      existing: existing,
      existingCategory: existingCategory,
    ),
  );
}

class BudgetFormSheet extends ConsumerStatefulWidget {
  const BudgetFormSheet({
    super.key,
    required this.month,
    required this.choices,
    this.existing,
    this.existingCategory,
  });

  final DateTime month;
  final List<Category> choices;
  final Budget? existing;
  final Category? existingCategory;

  @override
  ConsumerState<BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<BudgetFormSheet> {
  final _amount = TextEditingController();
  String? _categoryId;
  String? _error;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _categoryId = e.categoryId;
      _amount.text = ThousandsFormatter.format(e.amount.toString());
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    if (_categoryId == null) {
      setState(() => _error = 'Pilih kategori');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Masukkan jumlah anggaran lebih dari 0');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final err = await ref.read(budgetActionsProvider).save(
        categoryId: _categoryId!, month: widget.month, amount: amount);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      context.showSnack(err, error: true);
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus anggaran?',
      message: 'Anggaran untuk kategori ini di bulan ini akan dihapus.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final err = await ref.read(budgetActionsProvider).delete(widget.existing!.id);
    if (!mounted) return;
    if (err != null) {
      context.showSnack(err, error: true);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cat = widget.existingCategory;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _editing ? 'Ubah anggaran' : 'Anggaran baru',
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (_editing)
                  IconButton(
                    onPressed: _delete,
                    icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                  ),
              ],
            ),
            Text(Fmt.monthYear(widget.month),
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 20),
            Text('Kategori',
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            if (_editing && cat != null)
              Row(
                children: [
                  CategoryAvatar(icon: cat.icon, color: cat.color, size: 40),
                  const SizedBox(width: 12),
                  Text(cat.name,
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in widget.choices)
                    ChoiceChip(
                      avatar: Icon(c.icon, size: 18, color: c.color),
                      label: Text(c.name),
                      selected: _categoryId == c.id,
                      onSelected: (_) => setState(() => _categoryId = c.id),
                    ),
                ],
              ),
            const SizedBox(height: 20),
            Text('Batas anggaran',
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandsFormatter(),
              ],
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                hintText: '0',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: _editing ? 'Simpan perubahan' : 'Simpan anggaran',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
