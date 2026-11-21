import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../categories/domain/category.dart';
import '../../../categories/presentation/category_style.dart';
import '../../domain/category_suggester.dart';

class CategorySuggestionStrip extends StatelessWidget {
  const CategorySuggestionStrip({
    super.key,
    required this.hints,
    required this.options,
    required this.selectedId,
    required this.autoPicked,
    required this.onPick,
  });

  final List<CategoryHint> hints;
  final List<Category> options;
  final String? selectedId;
  final bool autoPicked;
  final ValueChanged<Category> onPick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final byId = {for (final c in options) c.id: c};
    final items = [
      for (final h in hints)
        if (byId.containsKey(h.categoryId)) (byId[h.categoryId]!, h),
    ];

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: items.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            autoPicked
                                ? 'Dipilih otomatis dari catatan. Ketuk saran lain untuk mengganti.'
                                : 'Saran kategori dari catatan',
                            key: ValueKey(autoPicked),
                            style: tt.labelMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        ChoiceChip(
                              avatar: Icon(
                                items[i].$1.icon,
                                size: 18,
                                color: items[i].$1.color,
                              ),
                              label: Text(
                                '${items[i].$1.name}  ${(items[i].$2.confidence * 100).round()}%',
                              ),
                              selected: selectedId == items[i].$1.id,
                              onSelected: (_) => onPick(items[i].$1),
                            )
                            .animate(key: ValueKey(items[i].$1.id))
                            .fadeIn(delay: (70 * i).ms, duration: 250.ms)
                            .slideY(
                              begin: 0.4,
                              delay: (70 * i).ms,
                              curve: Curves.easeOutBack,
                            ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
