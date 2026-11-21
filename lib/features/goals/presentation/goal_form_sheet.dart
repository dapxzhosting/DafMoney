import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/category_avatar.dart';
import '../../../core/widgets/form_bits.dart';
import '../../../core/widgets/primary_button.dart';
import '../../categories/presentation/category_style.dart';
import '../domain/savings_goal.dart';
import 'goal_providers.dart';

const _goalIcons = [
  'savings',
  'home',
  'car',
  'flight',
  'phone',
  'school',
  'gift',
  'heart',
  'work',
  'game',
];

Future<void> showGoalSheet(BuildContext context, {SavingsGoal? initial}) =>
    showFormSheet(context, GoalFormSheet(initial: initial));

class GoalFormSheet extends ConsumerStatefulWidget {
  const GoalFormSheet({super.key, this.initial});

  final SavingsGoal? initial;

  @override
  ConsumerState<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends ConsumerState<GoalFormSheet> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  final _saved = TextEditingController();
  late String _iconKey;
  late int _colorValue;
  DateTime? _deadline;
  String? _nameError;
  String? _targetError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.initial;
    _name.text = g?.name ?? '';
    _iconKey = g?.iconKey ?? 'savings';
    _colorValue = g?.colorValue ?? CategoryPalette.colors[5];
    _deadline = g?.deadline;
    if (g != null) _target.text = ThousandsFormatter.format('${g.target}');
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _saved.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final target = parseAmount(_target.text);
    final saved = _saved.text.trim().isEmpty
        ? 0
        : (parseAmount(_saved.text) ?? 0);
    setState(() {
      _nameError = name.isEmpty
          ? 'Nama wajib diisi'
          : (name.length > 40 ? 'Maksimal 40 karakter' : null);
      _targetError = (target == null || target <= 0)
          ? 'Target wajib diisi'
          : null;
    });
    if (_nameError != null || _targetError != null) return;
    setState(() => _saving = true);
    final actions = ref.read(goalActionsProvider);
    final err = widget.initial == null
        ? await actions.add(
            name: name,
            iconKey: _iconKey,
            colorValue: _colorValue,
            target: target!,
            saved: saved,
            deadline: _deadline,
          )
        : await actions.update(
            widget.initial!.id,
            name: name,
            iconKey: _iconKey,
            colorValue: _colorValue,
            target: target!,
            deadline: _deadline,
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = Color(_colorValue);
    final editing = widget.initial != null;

    return SheetBody(
      title: editing ? 'Ubah target' : 'Target tabungan baru',
      children: [
        Row(
          children: [
            CategoryAvatar(
              icon: CategoryIcons.byKey(_iconKey),
              color: color,
              size: 52,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nama target',
                  hintText: 'Mis. Liburan, Dana darurat, Laptop',
                  errorText: _nameError,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AmountField(
          controller: _target,
          label: 'Target dana',
          errorText: _targetError,
        ),
        if (!editing) ...[
          const SizedBox(height: 16),
          AmountField(controller: _saved, label: 'Sudah terkumpul (opsional)'),
        ],
        const SizedBox(height: 16),
        DateField(
          label: 'Tenggat (opsional)',
          value: _deadline,
          clearable: true,
          firstDate: DateTime.now(),
          onChanged: (d) => setState(() => _deadline = d),
        ),
        const SizedBox(height: 16),
        Text(
          'Ikon',
          style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final k in _goalIcons)
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _iconKey = k),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: k == _iconKey ? color : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: CategoryAvatar(
                    icon: CategoryIcons.byKey(k),
                    color: color,
                    size: 42,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in CategoryPalette.colors)
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _colorValue = c),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c == _colorValue
                          ? cs.onSurface
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: c == _colorValue
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
          ],
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

Future<void> showGoalFundsSheet(
  BuildContext context,
  SavingsGoal goal, {
  required bool deposit,
}) => showFormSheet(context, _GoalFundsSheet(goal: goal, deposit: deposit));

class _GoalFundsSheet extends ConsumerStatefulWidget {
  const _GoalFundsSheet({required this.goal, required this.deposit});

  final SavingsGoal goal;
  final bool deposit;

  @override
  ConsumerState<_GoalFundsSheet> createState() => _GoalFundsSheetState();
}

class _GoalFundsSheetState extends ConsumerState<_GoalFundsSheet> {
  final _amount = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = parseAmount(_amount.text);
    if (v == null || v <= 0) {
      setState(() => _error = 'Nominal wajib diisi');
      return;
    }
    if (!widget.deposit && v > widget.goal.saved) {
      setState(() => _error = 'Melebihi dana terkumpul');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final a = ref.read(goalActionsProvider);
    final err = widget.deposit
        ? await a.deposit(widget.goal.id, v)
        : await a.withdraw(widget.goal.id, v);
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
      title: widget.deposit
          ? 'Tambah dana · ${widget.goal.name}'
          : 'Tarik dana · ${widget.goal.name}',
      children: [
        AmountField(controller: _amount, autofocus: true, errorText: _error),
        const SizedBox(height: 8),
        Text(
          'Dana target hanya penanda tabungan. Saldo dompet tidak berubah.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            label: widget.deposit ? 'Tambah' : 'Tarik',
            loading: _saving,
            onPressed: _save,
          ),
        ),
      ],
    );
  }
}
