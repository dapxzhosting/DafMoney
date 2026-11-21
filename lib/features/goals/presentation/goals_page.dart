import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_images.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/animated_amount.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/motion.dart';
import '../../categories/presentation/category_style.dart';
import '../domain/savings_goal.dart';
import 'goal_form_sheet.dart';
import 'goal_providers.dart';

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Target tabungan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showGoalSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Target'),
      ),
      body: AsyncView<List<SavingsGoal>>(
        value: goals,
        onRetry: () => ref.invalidate(goalsProvider),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              image: AppImages.goalEmpty,
              icon: Icons.flag_rounded,
              title: 'Belum ada target tabungan',
              message:
                  'Tentukan tujuan seperti liburan atau dana darurat, lalu pantau progresnya.',
              actionLabel: 'Buat target',
              onAction: () => showGoalSheet(context),
            );
          }
          final totalSaved = items.fold<int>(0, (s, g) => s + g.saved);
          final totalTarget = items.fold<int>(0, (s, g) => s + g.target);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            children: [
              _Summary(saved: totalSaved, target: totalTarget),
              const SizedBox(height: 16),
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: StaggerIn(
                    index: i,
                    child: _GoalCard(goal: items[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.saved, required this.target});

  final int saved;
  final int target;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total tabungan target',
            style: tt.labelLarge?.copyWith(color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: 6),
          AnimatedAmount(
            value: saved,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'dari ${Fmt.rupiah(target)}',
            style: tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal});

  final SavingsGoal goal;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus target?',
      message: 'Target "${goal.name}" beserta progresnya akan dihapus.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final err = await ref.read(goalActionsProvider).delete(goal.id);
    if (err != null && context.mounted) context.showSnack(err, error: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = Color(goal.colorValue);
    final monthly = goal.monthlyNeeded(DateTime.now());
    final overdue =
        goal.deadline != null &&
        !goal.reached &&
        goal.deadline!.isBefore(DateTime.now());

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showGoalSheet(context, initial: goal),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: goal.progress),
                      duration: Motion.slow,
                      curve: Motion.enter,
                      builder: (_, v, __) => Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 64,
                            height: 64,
                            child: CircularProgressIndicator(
                              value: v,
                              strokeWidth: 7,
                              strokeCap: StrokeCap.round,
                              color: goal.reached ? Colors.green : color,
                              backgroundColor: color.withValues(alpha: 0.15),
                            ),
                          ),
                          Icon(
                            goal.reached
                                ? Icons.check_rounded
                                : CategoryIcons.byKey(goal.iconKey),
                            color: goal.reached ? Colors.green : color,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${Fmt.rupiah(goal.saved)} / ${Fmt.rupiah(goal.target)}',
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          goal.reached
                              ? 'Tercapai 🎉'
                              : '${Fmt.percent(goal.progress)} · kurang ${Fmt.rupiah(goal.remaining)}',
                          style: tt.labelMedium?.copyWith(
                            color: goal.reached ? Colors.green : color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _delete(context, ref),
                    icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                  ),
                ],
              ),
              if (goal.deadline != null) ...[
                const SizedBox(height: 10),
                Text(
                  overdue
                      ? 'Tenggat ${Fmt.dateShort(goal.deadline!)} sudah lewat'
                      : 'Tenggat ${Fmt.dateShort(goal.deadline!)}'
                            '${monthly == null ? '' : ' · tabung ±${Fmt.rupiah(monthly)}/bulan'}',
                  style: tt.bodySmall?.copyWith(
                    color: overdue ? cs.error : cs.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () =>
                          showGoalFundsSheet(context, goal, deposit: true),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Tambah dana'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: goal.saved == 0
                        ? null
                        : () => showGoalFundsSheet(
                            context,
                            goal,
                            deposit: false,
                          ),
                    child: const Text('Tarik'),
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
