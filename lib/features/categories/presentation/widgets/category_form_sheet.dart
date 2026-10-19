import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/entry_type.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/category.dart';
import '../category_style.dart';
import '../providers/category_providers.dart';

Future<void> showCategorySheet(
  BuildContext context, {
  required EntryType type,
  Category? initial,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => CategoryFormSheet(type: type, initial: initial),
  );
}

class CategoryFormSheet extends ConsumerStatefulWidget {
  const CategoryFormSheet({super.key, required this.type, this.initial});

  final EntryType type;
  final Category? initial;

  @override
  ConsumerState<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<CategoryFormSheet> {
  final _name = TextEditingController();
  late String _iconKey;
  late int _colorValue;
  String? _nameError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _name.text = c?.name ?? '';
    _iconKey = c?.iconKey ?? 'more';
    _colorValue = c?.colorValue ?? CategoryPalette.colors[4];
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Nama wajib diisi');
      return;
    }
    if (name.length > 40) {
      setState(() => _nameError = 'Maksimal 40 karakter');
      return;
    }
    setState(() {
      _nameError = null;
      _saving = true;
    });
    final actions = ref.read(categoryActionsProvider);
    final err = widget.initial == null
        ? await actions.add(
            name: name,
            type: widget.type,
            iconKey: _iconKey,
            colorValue: _colorValue)
        : await actions.update(widget.initial!.id,
            name: name, iconKey: _iconKey, colorValue: _colorValue);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      context.showSnack(err, error: true);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = Color(_colorValue);
    final editing = widget.initial != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              editing
                  ? 'Ubah kategori'
                  : 'Kategori ${widget.type.label.toLowerCase()} baru',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                CategoryAvatar(
                    icon: CategoryIcons.byKey(_iconKey), color: color, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Nama kategori',
                      errorText: _nameError,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Ikon',
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final e in CategoryIcons.all.entries)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _iconKey = e.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: e.key == _iconKey
                            ? color.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: e.key == _iconKey
                              ? color
                              : cs.outlineVariant,
                          width: e.key == _iconKey ? 1.8 : 1,
                        ),
                      ),
                      child: Icon(e.value,
                          size: 22,
                          color: e.key == _iconKey
                              ? color
                              : cs.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Warna',
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final v in CategoryPalette.colors)
                  GestureDetector(
                    onTap: () => setState(() => _colorValue = v),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Color(v),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: v == _colorValue
                              ? cs.onSurface
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: v == _colorValue
                          ? const Icon(Icons.check_rounded,
                              size: 18, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: editing ? 'Simpan perubahan' : 'Tambah kategori',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
