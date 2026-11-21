import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/reminder_provider.dart';
import '../../../../core/utils/snackbar.dart';

class ReminderSection extends ConsumerWidget {
  const ReminderSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(reminderProvider);
    final notifier = ref.read(reminderProvider.notifier);
    final budgetAlerts = ref.watch(budgetAlertsEnabledProvider);

    Widget icon(IconData i) => Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(i, size: 20, color: cs.primary),
    );

    return Column(
      children: [
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          secondary: icon(Icons.notifications_active_rounded),
          title: const Text(
            'Pengingat harian',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Diingatkan mencatat transaksi. Dilewati bila hari ini sudah mencatat.',
          ),
          value: state.enabled,
          onChanged: notifier.setEnabled,
        ),
        const Divider(height: 1, indent: 64),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          secondary: icon(Icons.speed_rounded),
          title: const Text(
            'Peringatan anggaran',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Notifikasi saat pengeluaran mencapai 80% dan 100% anggaran.',
          ),
          value: budgetAlerts,
          onChanged: ref.read(budgetAlertsEnabledProvider.notifier).set,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: state.enabled
              ? Column(
                  children: [
                    const Divider(height: 1, indent: 64),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: icon(Icons.schedule_rounded),
                      title: const Text(
                        'Waktu pengingat',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(state.time.format(context)),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: state.time,
                          helpText: 'Pilih jam pengingat',
                        );
                        if (picked != null) await notifier.setTime(picked);
                      },
                    ),
                    const Divider(height: 1, indent: 64),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: icon(Icons.send_rounded),
                      title: const Text(
                        'Kirim notifikasi uji',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Pastikan notifikasi muncul'),
                      onTap: () async {
                        await notifier.sendTest();
                        if (context.mounted) {
                          context.showSnack(
                            'Notifikasi uji dikirim. Cek bilah notifikasi.',
                          );
                        }
                      },
                    ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
