import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../transactions/domain/money_transaction.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../domain/wallet.dart';
import '../providers/wallet_providers.dart';
import '../wallet_style.dart';
import '../widgets/wallet_form_sheet.dart';

class WalletsPage extends ConsumerWidget {
  const WalletsPage({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, Wallet w) async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus dompet?',
      message:
          'Dompet "${w.name}" akan dihapus. Transaksinya tidak ikut terhapus dan menjadi "tanpa dompet".',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final err = await ref.read(walletActionsProvider).delete(w.id);
    if (!context.mounted) return;
    if (err != null) context.showSnack(err, error: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider);
    final totals = ref.watch(walletTotalsProvider).valueOrNull ??
        const <String, Balance>{};
    final all = ref.watch(balanceProvider).valueOrNull ?? Balance.zero;
    final profileInitial =
        ref.watch(userProfileProvider).valueOrNull?.initialBalance ?? 0;
    final walletsInitial = ref.watch(walletsInitialSumProvider);
    final totalBalance = all.total + profileInitial + walletsInitial;
    final unassigned = totals[''];

    return Scaffold(
      appBar: AppBar(title: const Text('Dompet')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showWalletSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Dompet'),
      ),
      body: AsyncView<List<Wallet>>(
        value: wallets,
        onRetry: () => ref.invalidate(walletsProvider),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Belum ada dompet',
              message:
                  'Pisahkan saldo Anda, mis. Tunai, rekening bank, atau dompet digital.',
              actionLabel: 'Tambah dompet',
              onAction: () => showWalletSheet(context),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            children: [
              _TotalCard(total: totalBalance),
              const SizedBox(height: 16),
              for (final w in list) ...[
                _WalletCard(
                  wallet: w,
                  balance: w.initialBalance + (totals[w.id]?.total ?? 0),
                  onTap: () => showWalletSheet(context, initial: w),
                  onDelete: () => _delete(context, ref, w),
                ),
                const SizedBox(height: 10),
              ],
              if (unassigned != null && (unassigned.total != 0))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _UnassignedCard(net: unassigned.total),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total});

  final int total;

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
          Text('Total saldo',
              style: tt.labelLarge?.copyWith(color: cs.onPrimaryContainer)),
          const SizedBox(height: 6),
          Text(
            Fmt.rupiah(total),
            style: tt.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800, color: cs.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.wallet,
    required this.balance,
    required this.onTap,
    required this.onDelete,
  });

  final Wallet wallet;
  final int balance;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fin = context.finance;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(
            children: [
              CategoryAvatar(icon: wallet.icon, color: wallet.color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(wallet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      Fmt.rupiah(balance),
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: balance < 0 ? fin.expense : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: cs.error),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnassignedCard extends StatelessWidget {
  const _UnassignedCard({required this.net});

  final int net;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CategoryAvatar(
                icon: Icons.help_outline_rounded,
                color: const Color(0xFF9CA3AF)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tanpa dompet',
                      style: tt.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Selisih transaksi yang belum dikaitkan ke dompet',
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(Fmt.rupiah(net),
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
