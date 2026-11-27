import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/sound_provider.dart';
import '../../../../core/services/sound_service.dart';

class SoundSection extends ConsumerWidget {
  const SoundSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final enabled = ref.watch(soundEnabledProvider);

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.volume_up_rounded, size: 20, color: cs.primary),
      ),
      title: const Text(
        'Efek suara',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: const Text('Bunyi "dongg" saat transaksi berhasil dicatat.'),
      value: enabled,
      onChanged: (v) async {
        await ref.read(soundEnabledProvider.notifier).set(v);
        if (v) SoundService.preview();
      },
    );
  }
}
