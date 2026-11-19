import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/entry_type.dart';
import '../../../core/theme/app_spacing.dart';
import '../../categories/presentation/category_style.dart';
import '../../categories/presentation/providers/category_providers.dart';
import 'challenge_providers.dart';

/// Memilih kategori dan target hari, lalu memulai tantangan.
Future<void> showChallengeSetup(BuildContext context, {int carryBest = 0}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (_) => _SetupSheet(carryBest: carryBest),
  );
}

class _SetupSheet extends ConsumerStatefulWidget {
  const _SetupSheet({required this.carryBest});

  final int carryBest;

  @override
  ConsumerState<_SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends ConsumerState<_SetupSheet> {
  String? _categoryId;
  int _target = 7;

  static const _targets = [7, 14, 30, 60];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cats = (ref.watch(categoriesProvider).valueOrNull ?? const [])
        .where((c) => c.type == EntryType.expense)
        .toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mulai tantangan',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Bertahan tanpa pengeluaran di satu kategori. Satu transaksi di kategori itu akan mengulang hitungan dari nol.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: Gap.md),
            Text(
              'Kategori yang ingin dihentikan',
              style: tt.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Gap.xs),
            if (cats.isEmpty)
              Text(
                'Belum ada kategori pengeluaran.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in cats)
                    ChoiceChip(
                      avatar: Icon(c.icon, size: 18, color: c.color),
                      label: Text(c.name),
                      selected: _categoryId == c.id,
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _categoryId = c.id);
                      },
                    ),
                ],
              ),
            const SizedBox(height: Gap.md),
            Text(
              'Target',
              style: tt.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Gap.xs),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (final t in _targets)
                    ButtonSegment(value: t, label: Text('$t hari')),
                ],
                selected: {_target},
                onSelectionChanged: (s) => setState(() => _target = s.first),
              ),
            ),
            const SizedBox(height: Gap.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _categoryId == null
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        await ref
                            .read(challengeProvider.notifier)
                            .start(
                              categoryId: _categoryId!,
                              targetDays: _target,
                              carryBest: widget.carryBest,
                            );
                        if (context.mounted) Navigator.of(context).pop();
                      },
                icon: const Icon(Icons.local_fire_department_rounded),
                label: const Text('Mulai tantangan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
