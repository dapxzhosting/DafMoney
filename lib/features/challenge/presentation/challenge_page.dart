import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../categories/presentation/category_style.dart';
import '../../categories/presentation/providers/category_providers.dart';
import '../domain/no_spend_challenge.dart';
import 'challenge_providers.dart';
import 'challenge_setup_sheet.dart';
import 'challenge_widgets.dart';

class ChallengePage extends ConsumerWidget {
  const ChallengePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(challengeProgressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tantangan')),
      body: progress == null
          ? const _NoChallenge()
          : _ActiveChallenge(progress: progress),
    );
  }
}

class _NoChallenge extends StatelessWidget {
  const _NoChallenge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FlameIcon(size: 96, lit: true)
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(
                  begin: const Offset(0.5, 0.5),
                  duration: 600.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: Gap.md),
            Text(
              'Tantangan hari tanpa jajan',
              textAlign: TextAlign.center,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: Gap.xs),
            Text(
              'Pilih satu kategori, lalu bertahan tanpa belanja di sana. Kumpulkan hari beruntun dan buka lencananya.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ).animate().fadeIn(delay: 320.ms),
            const SizedBox(height: Gap.lg),
            FilledButton.icon(
              onPressed: () => showChallengeSetup(context),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Mulai tantangan'),
            ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.3),
          ],
        ),
      ),
    );
  }
}

class _ActiveChallenge extends ConsumerWidget {
  const _ActiveChallenge({required this.progress});

  final ChallengeProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fin = context.finance;
    final cats = ref.watch(categoryMapProvider);
    final look = resolveCategory(cats, progress.challenge.categoryId);

    final message = progress.completed
        ? 'Target tercapai! Kamu luar biasa. Siap naik level?'
        : progress.spentToday
        ? 'Hari ini ada pengeluaran di ${look.name}. Besok mulai lagi, kamu pasti bisa!'
        : progress.streak == 0
        ? 'Tantangan dimulai hari ini. Semangat!'
        : 'Tinggal ${progress.target - progress.streak} hari lagi menuju target.';

    final lit = !progress.spentToday;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xs, Gap.page, 40),
          children: [
            Container(
                  padding: const EdgeInsets.all(Gap.lg),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      colors: lit
                          ? const [Color(0xFFFF6D00), Color(0xFF9F1239)]
                          : const [Color(0xFF475569), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Tanpa ${look.name}',
                        style: tt.titleSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: Gap.sm),
                      ProgressRing(
                        progress: progress.ratio,
                        size: 220,
                        stroke: 14,
                        color: Colors.white,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FlameIcon(size: 56, lit: lit),
                            TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end: progress.streak.toDouble(),
                              ),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, __) => Text(
                                '${v.round()}',
                                style: tt.displayMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                            ),
                            Text(
                              'dari ${progress.target} hari',
                              style: tt.labelMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Gap.md),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: tt.bodyMedium?.copyWith(
                          color: Colors.white,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.08, curve: Curves.easeOutCubic),
            const SizedBox(height: Gap.md),

            _Panel(
              title: '7 hari terakhir',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < progress.last7.length; i++)
                    _DayDot(
                      mark: progress.last7[i],
                      index: i,
                      cleanColor: fin.income,
                      spentColor: fin.expense,
                      label: _dayLabel(i),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Gap.md),

            Row(
              children: [
                _Stat(
                  icon: Icons.emoji_events_rounded,
                  label: 'Rekor terbaik',
                  value: '${progress.best} hari',
                ),
                const SizedBox(width: Gap.xs),
                _Stat(
                  icon: Icons.flag_rounded,
                  label: 'Lencana berikutnya',
                  value: progress.nextMilestone == null
                      ? 'Semua terbuka'
                      : '${progress.nextMilestone} hari',
                ),
              ],
            ),
            const SizedBox(height: Gap.md),

            _Panel(
              title: 'Lencana',
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: Gap.sm,
                crossAxisSpacing: Gap.sm,
                childAspectRatio: 1,
                children: [
                  for (var i = 0; i < challengeMilestones.length; i++)
                    _Badge(
                      days: challengeMilestones[i],
                      unlocked: progress.best >= challengeMilestones[i],
                      index: i,
                    ),
                ],
              ),
            ),
            const SizedBox(height: Gap.lg),

            if (progress.completed)
              FilledButton.icon(
                onPressed: () =>
                    showChallengeSetup(context, carryBest: progress.best),
                icon: const Icon(Icons.rocket_launch_rounded),
                label: const Text('Tantangan baru yang lebih tinggi'),
              )
            else
              OutlinedButton.icon(
                onPressed: () =>
                    showChallengeSetup(context, carryBest: progress.best),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Ganti kategori atau target'),
              ),
            const SizedBox(height: Gap.xs),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: cs.error),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Hentikan tantangan?',
                  message: 'Hitungan hari beruntun akan dihapus.',
                  confirmLabel: 'Hentikan',
                );
                if (ok == true) {
                  HapticFeedback.mediumImpact();
                  await ref.read(challengeProvider.notifier).stop();
                }
              },
              child: const Text('Hentikan tantangan'),
            ),
          ],
        ),
        if (progress.completed) const Positioned.fill(child: ConfettiBurst()),
      ],
    );
  }

  static String _dayLabel(int i) {
    final d = DateTime.now().subtract(Duration(days: 6 - i));
    const names = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return names[d.weekday - 1];
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: Gap.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.sm + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(height: 8),
              Text(
                value,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                label,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.mark,
    required this.index,
    required this.cleanColor,
    required this.spentColor,
    required this.label,
  });

  final DayMark mark;
  final int index;
  final Color cleanColor;
  final Color spentColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final (Color bg, IconData? icon) = switch (mark) {
      DayMark.clean => (cleanColor, Icons.check_rounded),
      DayMark.spent => (spentColor, Icons.close_rounded),
      DayMark.before => (cs.surfaceContainerHighest, null),
    };

    return Column(
      children: [
        Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
              child: icon == null
                  ? null
                  : Icon(icon, size: 20, color: Colors.white),
            )
            .animate()
            .scale(
              begin: Offset.zero,
              delay: (index * 70).ms,
              duration: 400.ms,
              curve: Curves.easeOutBack,
            )
            .fadeIn(delay: (index * 70).ms),
        const SizedBox(height: 6),
        Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.days,
    required this.unlocked,
    required this.index,
  });

  final int days;
  final bool unlocked;
  final int index;

  static const _icons = [
    Icons.local_fire_department_rounded,
    Icons.whatshot_rounded,
    Icons.bolt_rounded,
    Icons.emoji_events_rounded,
    Icons.military_tech_rounded,
    Icons.workspace_premium_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final icon = _icons[index % _icons.length];

    Widget badge = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: unlocked
            ? const LinearGradient(
                colors: [Color(0xFFFFB300), Color(0xFFFF6D00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: unlocked
            ? null
            : cs.surfaceContainerHighest.withValues(alpha: 0.6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            unlocked ? icon : Icons.lock_rounded,
            size: 30,
            color: unlocked ? Colors.white : cs.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          Text(
            '$days hari',
            style: tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: unlocked ? Colors.white : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    badge = badge
        .animate()
        .fadeIn(delay: (index * 90).ms, duration: 300.ms)
        .scale(
          begin: const Offset(0.6, 0.6),
          delay: (index * 90).ms,
          duration: 550.ms,
          curve: Curves.elasticOut,
        );

    if (unlocked) {
      badge = badge
          .animate(onPlay: (c) => c.repeat())
          .shimmer(
            delay: (1800 + index * 400).ms,
            duration: 1400.ms,
            color: Colors.white.withValues(alpha: 0.35),
          );
    }
    return badge;
  }
}
