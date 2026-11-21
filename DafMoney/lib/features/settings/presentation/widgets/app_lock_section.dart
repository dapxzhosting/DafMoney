import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_lock_providers.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/utils/snackbar.dart';

/// Pengaturan kunci aplikasi (sidik jari / wajah / PIN perangkat).
class AppLockSection extends ConsumerWidget {
  const AppLockSection({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool on) async {
    final notifier = ref.read(appLockEnabledProvider.notifier);
    if (on) {
      if (!await BiometricService.isSupported()) {
        if (context.mounted) {
          context.showSnack(
            'Aktifkan sidik jari atau PIN/pola di pengaturan perangkat dulu.',
            error: true,
          );
        }
        return;
      }
      final r = await BiometricService.authenticate(
        reason: 'Verifikasi untuk mengaktifkan kunci aplikasi',
      );
      if (r == AuthResult.success) {
        await notifier.set(true);
      } else if (context.mounted) {
        context.showSnack('Verifikasi gagal. Kunci aplikasi tidak diaktifkan.', error: true);
      }
      return;
    }
    // Mematikan juga harus lolos verifikasi, supaya orang lain yang memegang
    // ponsel yang sedang terbuka tidak bisa mematikannya begitu saja.
    final r = await BiometricService.authenticate(
      reason: 'Verifikasi untuk mematikan kunci aplikasi',
    );
    // Jika perangkat sudah tidak punya kunci layar, kunci memang tak bisa
    // dipakai lagi; izinkan mematikannya.
    if (r == AuthResult.success || r == AuthResult.unavailable) {
      await notifier.set(false);
    } else if (context.mounted) {
      context.showSnack('Verifikasi gagal. Kunci tetap aktif.', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final enabled = ref.watch(appLockEnabledProvider);
    final grace = ref.watch(appLockGraceProvider);
    String label(int s) => s == 0 ? 'Langsung' : (s == 60 ? '1 menit' : '5 menit');

    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.fingerprint_rounded),
          title: const Text(
            'Kunci aplikasi',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text('Sidik jari, wajah, atau PIN/pola perangkat'),
          value: enabled,
          onChanged: (v) => _toggle(context, ref, v),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: enabled
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kunci kembali setelah ditinggalkan',
                        style: tt.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: [
                            for (final s in AppLockGrace.options)
                              ButtonSegment(value: s, label: Text(label(s))),
                          ],
                          selected: {grace},
                          onSelectionChanged: (v) => ref
                              .read(appLockGraceProvider.notifier)
                              .set(v.first),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
