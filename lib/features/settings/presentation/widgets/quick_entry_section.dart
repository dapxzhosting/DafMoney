import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/quick_entry_provider.dart';

class QuickEntrySection extends ConsumerWidget {
  const QuickEntrySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final enabled = ref.watch(quickEntryProvider);

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.bolt_rounded, size: 20, color: cs.primary),
      ),
      title: const Text(
        'Catat cepat dari notifikasi',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: const Text(
        'Tambah pemasukan/pengeluaran langsung dari bar notifikasi tanpa '
        'membuka app. Ketik mis. "makan siang 25rb".',
      ),
      value: enabled,
      onChanged: (v) => ref.read(quickEntryProvider.notifier).set(v),
    );
  }
}
