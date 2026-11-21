import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_images.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/animated_amount.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/motion.dart';
import '../domain/debt.dart';
import 'debt_form_sheet.dart';
import 'debt_providers.dart';

class DebtsPage extends ConsumerStatefulWidget {
  const DebtsPage({super.key});

  @override
  ConsumerState<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends ConsumerState<DebtsPage> {
  DebtKind _kind = DebtKind.owe;

  @override
  Widget build(BuildContext context) {
    final debts = ref.watch(debtsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Utang & piutang')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDebtSheet(context, kind: _kind),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Catatan'),
      ),
      body: AsyncView<List<Debt>>(
        value: debts,
        onRetry: () => ref.invalidate(debtsProvider),
        data: (all) {
          final owe = outstanding(all, DebtKind.owe);
          final lend = outstanding(all, DebtKind.lend);
          final items = all.where((d) => d.kind == _kind).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _TotalTile(
                      label: 'Utang saya',
                      value: owe,
                      color: context.finance.expense,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TotalTile(
                      label: 'Piutang',
                      value: lend,
                      color: context.finance.income,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 12),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: EmptyState(
                    image: _kind == DebtKind.owe ? AppImages.utang : AppImages.piutang,
                    icon: Icons.handshake_rounded,
                    title: _kind == DebtKind.owe
                        ? 'Tidak ada utang'
                        : 'Tidak ada piutang',
                    message: _kind == DebtKind.owe
                        ? 'Catat uang yang Anda pinjam supaya tidak lupa membayarnya.'
                        : 'Catat uang yang Anda pinjamkan dan pantau siapa yang belum membayar.',
                    actionLabel: 'Tambah catatan',
                    onAction: () => showDebtSheet(context, kind: _kind),
                  ),
                )
              else
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: StaggerIn(
                      index: i,
                      child: _DebtCard(debt: items[i]),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label belum lunas',
            style: tt.labelMedium?.copyWith(color: color),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedAmount(
              value: value,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtCard extends ConsumerWidget {
  const _DebtCard({required this.debt});

  final Debt debt;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus catatan?',
      message: 'Catatan dengan ${debt.person} akan dihapus permanen.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final err = await ref.read(debtActionsProvider).delete(debt);
    if (err != null && context.mounted) context.showSnack(err, error: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fin = context.finance;
    final isOwe = debt.kind == DebtKind.owe;
    final color = isOwe ? fin.expense : fin.income;
    final overdue = debt.isOverdue(DateTime.now());

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showDebtSheet(context, initial: debt),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Text(
                      debt.person.characters.first.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debt.person,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (debt.note.isNotEmpty)
                          Text(
                            debt.note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        debt.settled
                            ? 'Lunas ✓'
                            : Fmt.rupiah(debt.remaining),
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: debt.settled ? Colors.green : color,
                        ),
                      ),
                      if (!debt.settled && debt.paid > 0)
                        Text(
                          'dari ${Fmt.rupiah(debt.amount)}',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => _delete(context, ref),
                    icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: debt.progress),
                  duration: Motion.slow,
                  curve: Motion.enter,
                  builder: (_, v, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      color: debt.settled ? Colors.green : color,
                      backgroundColor: color.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (debt.dueDate != null)
                    Expanded(
                      child: Text(
                        overdue
                            ? 'Terlambat · jatuh tempo ${Fmt.dateShort(debt.dueDate!)}'
                            : 'Jatuh tempo ${Fmt.dateShort(debt.dueDate!)}',
                        style: tt.labelMedium?.copyWith(
                          color: overdue ? cs.error : cs.onSurfaceVariant,
                          fontWeight: overdue ? FontWeight.w700 : null,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (!debt.settled)
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => showDebtPaymentSheet(context, debt),
                      child: Text(isOwe ? 'Bayar' : 'Terima'),
                    )
                  else
                    TextButton(
                      onPressed: () => showDebtPaymentSheet(context, debt),
                      child: const Text('Reset'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
