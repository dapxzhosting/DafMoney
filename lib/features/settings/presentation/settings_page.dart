import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import 'providers/settings_providers.dart';
import 'widgets/settings_sheets.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _run(
    BuildContext context,
    Future<String?> Function() task,
    String successMessage,
  ) async {
    final err = await task();
    if (!context.mounted) return;
    context.showSnack(err ?? successMessage, error: err != null);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final user = ref.watch(authStateProvider).valueOrNull;
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final mode = ref.watch(themeModeProvider);
    final actions = ref.read(settingsActionsProvider);

    final name = (profile?.name.trim().isNotEmpty ?? false)
        ? profile!.name.trim()
        : ((user?.displayName?.trim().isNotEmpty ?? false)
            ? user!.displayName!.trim()
            : 'Pengguna');
    final initial = profile?.initialBalance ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      name.characters.first.toUpperCase(),
                      style: tt.titleLarge?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(user?.email ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.verified_rounded,
                                size: 14, color: cs.primary),
                            const SizedBox(width: 4),
                            Text('Email terverifikasi',
                                style: tt.labelSmall
                                    ?.copyWith(color: cs.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () =>
                        showSettingsSheet(context, EditNameSheet(initial: name)),
                    icon: const Icon(Icons.edit_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          _Group(title: 'Keuangan', children: [
            _Tile(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Saldo awal',
              subtitle: Fmt.rupiah(initial),
              onTap: () => showSettingsSheet(
                  context, InitialBalanceSheet(current: initial)),
            ),
            _Tile(
              icon: Icons.category_rounded,
              title: 'Kelola kategori',
              subtitle: 'Tambah, ubah, atau hapus kategori',
              onTap: () => context.push(AppRoutes.categories),
            ),
          ]),
          _Group(title: 'Tampilan', children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tema',
                      style: tt.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_rounded),
                          label: Text('Sistem'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_rounded),
                          label: Text('Terang'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_rounded),
                          label: Text('Gelap'),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (s) => ref
                          .read(themeModeProvider.notifier)
                          .setMode(s.first),
                    ),
                  ),
                ],
              ),
            ),
          ]),
          _Group(title: 'Keamanan', children: [
            _Tile(
              icon: Icons.lock_reset_rounded,
              title: 'Ubah kata sandi',
              onTap: () =>
                  showSettingsSheet(context, const ChangePasswordSheet()),
            ),
          ]),
          _Group(title: 'Data', children: [
            _Tile(
              icon: Icons.file_download_outlined,
              title: 'Salin semua transaksi (CSV)',
              subtitle: 'Tempel ke Excel atau Google Sheets',
              onTap: () => _run(context, actions.copyAllCsv,
                  'Semua transaksi disalin sebagai CSV.'),
            ),
            _Tile(
              icon: Icons.delete_sweep_rounded,
              title: 'Hapus semua transaksi',
              subtitle: 'Kategori dan anggaran tetap ada',
              danger: true,
              onTap: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Hapus semua transaksi?',
                  message:
                      'Seluruh riwayat transaksi akan dihapus permanen dan tidak bisa dikembalikan.',
                  confirmLabel: 'Hapus semua',
                  destructive: true,
                );
                if (!ok || !context.mounted) return;
                await _run(context, actions.deleteAllTransactions,
                    'Semua transaksi dihapus.');
              },
            ),
          ]),
          _Group(title: 'Akun', children: [
            _Tile(
              icon: Icons.logout_rounded,
              title: 'Keluar',
              onTap: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Keluar dari akun?',
                  message: 'Anda perlu masuk lagi untuk mengakses data.',
                  confirmLabel: 'Keluar',
                  destructive: true,
                );
                if (ok) {
                  await ref.read(authControllerProvider.notifier).signOut();
                }
              },
            ),
            _Tile(
              icon: Icons.person_remove_rounded,
              title: 'Hapus akun',
              subtitle: 'Hapus akun dan semua datanya',
              danger: true,
              onTap: () =>
                  showSettingsSheet(context, const DeleteAccountSheet()),
            ),
          ]),
          _Group(title: 'Tentang', children: [
            _Tile(
              icon: Icons.info_outline_rounded,
              title: 'Tentang ${AppConstants.appName}',
              subtitle: 'Versi ${AppConstants.appVersion}',
              onTap: () => showAboutDialog(
                context: context,
                applicationName: AppConstants.appName,
                applicationVersion: AppConstants.appVersion,
                applicationIcon: Icon(Icons.savings_rounded,
                    size: 40, color: cs.primary),
                children: const [
                  SizedBox(height: 12),
                  Text(
                      'Aplikasi pencatat keuangan pribadi. Data Anda tersimpan di akun Firebase milik Anda sendiri dan hanya bisa diakses oleh Anda.'),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: tt.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 64),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = danger ? cs.error : cs.primary;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: accent),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: danger ? cs.error : null,
        ),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
    );
  }
}
