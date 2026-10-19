import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/entry_type.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/category.dart';
import '../category_style.dart';
import '../providers/category_providers.dart';
import '../widgets/category_form_sheet.dart';

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  EntryType _type = EntryType.expense;

  Future<void> _delete(Category c) async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus kategori?',
      message:
          'Kategori "${c.name}" beserta anggarannya akan dihapus. Kategori yang masih dipakai transaksi tidak bisa dihapus.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final err = await ref.read(categoryActionsProvider).delete(c.id);
    if (!mounted) return;
    if (err != null) context.showSnack(err, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kategori')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCategorySheet(context, type: _type),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Kategori'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<EntryType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: EntryType.expense, label: Text('Pengeluaran')),
                  ButtonSegment(
                      value: EntryType.income, label: Text('Pemasukan')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
            ),
          ),
          Expanded(
            child: AsyncView<List<Category>>(
              value: cats,
              onRetry: () => ref.invalidate(categoriesProvider),
              data: (all) {
                final list = all.where((c) => c.type == _type).toList();
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.category_rounded,
                    title: 'Belum ada kategori',
                    message: 'Tambahkan kategori ${_type.label.toLowerCase()} pertama Anda.',
                    actionLabel: 'Tambah kategori',
                    onAction: () => showCategorySheet(context, type: _type),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final c = list[i];
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => showCategorySheet(context,
                            type: c.type, initial: c),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              CategoryAvatar(icon: c.icon, color: c.color),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  c.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _delete(c),
                                icon: Icon(Icons.delete_outline_rounded,
                                    color:
                                        Theme.of(context).colorScheme.error),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
