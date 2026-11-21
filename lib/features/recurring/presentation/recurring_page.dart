import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_images.dart';
import '../../../core/models/entry_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/category_avatar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/motion.dart';
import '../../categories/presentation/category_style.dart';
import '../../categories/presentation/providers/category_providers.dart';
import '../../wallets/presentation/providers/wallet_providers.dart';
import '../domain/recurring_entry.dart';
import 'recurring_form_sheet.dart';
import 'recurring_providers.dart';

class RecurringPage extends ConsumerWidget {
  const RecurringPage({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    RecurringEntry r,
  ) async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus transaksi berulang?',
      message:
          'Aturan ini dihapus. Transaksi yang sudah tercatat tidak ikut terhapus.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final err = await ref.read(recurringActionsProvider).delete(r.id);
    if (!context.mounted) return;
    if (err != null) context.showSnack(err, error: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(recurringListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi berulang')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showRecurringSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah'),
      ),
      body: AsyncView<List<RecurringEntry>>(
        value: list,
        onRetry: () => ref.invalidate(recurringListProvider),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              image: AppImages.recurringEmpty,
              icon: Icons.event_repeat_rounded,
              title: 'Belum ada transaksi berulang',
              message:
                  'Catat gaji, langganan, atau cicilan sekali saja. DafMoney yang mencatatnya setiap periode.',
              actionLabel: 'Tambah transaksi berulang',
              onAction: () => showRecurringSheet(context),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => StaggerIn(
              index: i,
              child: _RecurringCard(
                entry: items[i],
                onEdit: () => showRecurringSheet(context, initial: items[i]),
                onDelete: () => _delete(context, ref, items[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecurringCard extends ConsumerWidget {
  const _RecurringCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final RecurringEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fin = context.finance;
    final look = resolveCategory(ref.watch(categoryMapProvider), entry.categoryId);
    final wallet = entry.walletId == null
        ? null
        : ref.watch(walletMapProvider)[entry.walletId!];
    final isIncome = entry.type == EntryType.income;
    final title = entry.note.isEmpty ? look.name : entry.note;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              Opacity(
                opacity: entry.active ? 1 : 0.45,
                child: CategoryAvatar(icon: look.icon, color: look.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.frequency.label} · ${entry.active ? 'berikutnya ${Fmt.dateShort(entry.nextDate)}' : 'dijeda'}'
                      '${wallet == null ? '' : ' · ${wallet.name}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${isIncome ? '+' : '-'}${Fmt.rupiah(entry.amount)}',
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isIncome ? fin.income : fin.expense,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: entry.active,
                onChanged: (v) async {
                  final err = await ref
                      .read(recurringActionsProvider)
                      .setActive(entry.id, v);
                  if (err != null && context.mounted) {
                    context.showSnack(err, error: true);
                  }
                  if (v) ref.read(recurringActionsProvider).processDue();
                },
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
