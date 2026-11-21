import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/section_header.dart';
import '../../wallets/presentation/providers/wallet_providers.dart';
import '../domain/wallet_transfer.dart';
import 'transfer_providers.dart';

class TransferHistory extends ConsumerWidget {
  const TransferHistory({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final transfers =
        ref.watch(transfersProvider).valueOrNull ?? const <WalletTransfer>[];
    final wallets = ref.watch(walletMapProvider);
    if (transfers.isEmpty) return const SizedBox.shrink();
    final recent = transfers.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const SectionHeader(title: 'Transfer terbaru'),
        const SizedBox(height: 8),
        for (final t in recent)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.secondaryContainer,
                child: Icon(
                  Icons.swap_horiz_rounded,
                  color: cs.onSecondaryContainer,
                ),
              ),
              title: Text(
                '${wallets[t.fromWalletId]?.name ?? 'Dompet dihapus'} → ${wallets[t.toWalletId]?.name ?? 'Dompet dihapus'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${Fmt.dateShort(t.date)}${t.note.isEmpty ? '' : ' · ${t.note}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Fmt.rupiah(t.amount),
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                    onPressed: () async {
                      final ok = await confirmDialog(
                        context,
                        title: 'Hapus transfer?',
                        message: 'Saldo kedua dompet kembali seperti sebelum transfer ini.',
                        confirmLabel: 'Hapus',
                        destructive: true,
                      );
                      if (!ok || !context.mounted) return;
                      final err = await ref
                          .read(transferActionsProvider)
                          .delete(t.id);
                      if (err != null && context.mounted) {
                        context.showSnack(err, error: true);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
