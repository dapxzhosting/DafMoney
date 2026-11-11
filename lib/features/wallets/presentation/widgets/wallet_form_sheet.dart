import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/amount_formatter.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../categories/presentation/category_style.dart';
import '../../domain/wallet.dart';
import '../providers/wallet_providers.dart';
import '../wallet_style.dart';

Future<void> showWalletSheet(BuildContext context, {Wallet? initial}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => WalletFormSheet(initial: initial),
  );
}

class WalletFormSheet extends ConsumerStatefulWidget {
  const WalletFormSheet({super.key, this.initial});

  final Wallet? initial;

  @override
  ConsumerState<WalletFormSheet> createState() => _WalletFormSheetState();
}

class _WalletFormSheetState extends ConsumerState<WalletFormSheet> {
  final _name = TextEditingController();
  final _balance = TextEditingController();
  late String _iconKey;
  late int _colorValue;
  String? _nameError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final w = widget.initial;
    _name.text = w?.name ?? '';
    _balance.text = (w != null && w.initialBalance > 0)
        ? ThousandsFormatter.format(w.initialBalance.toString())
        : '';
    _iconKey = w?.iconKey ?? WalletIcons.defaultKey;
    _colorValue = w?.colorValue ?? CategoryPalette.colors[5];
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
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
    final balance = _balance.text.trim().isEmpty
        ? 0
        : (parseAmount(_balance.text) ?? 0);
    setState(() {
      _nameError = null;
      _saving = true;
    });
    final actions = ref.read(walletActionsProvider);
    final err = widget.initial == null
        ? await actions.add(
            name: name,
            iconKey: _iconKey,
            colorValue: _colorValue,
            initialBalance: balance)
        : await actions.update(widget.initial!.id,
            name: name,
            iconKey: _iconKey,
            colorValue: _colorValue,
            initialBalance: balance);
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
              editing ? 'Ubah dompet' : 'Dompet baru',
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
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Nama dompet',
                      hintText: 'Mis. Tunai, BCA, DANA',
                      errorText: _nameError,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _balance,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandsFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'Saldo awal (opsional)',
                prefixText: 'Rp ',
                hintText: '0',
              ),
            ),
            const SizedBox(height: 20),
            Text('Ikon',
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final key in WalletIcons.keys)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _iconKey = key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: key == _iconKey
                            ? color.withValues(alpha: 0.18)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: key == _iconKey ? color : cs.outlineVariant,
                          width: key == _iconKey ? 1.8 : 1,
                        ),
                      ),
                      child: Icon(CategoryIcons.byKey(key),
                          size: 22,
                          color:
                              key == _iconKey ? color : cs.onSurfaceVariant),
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
              label: editing ? 'Simpan perubahan' : 'Tambah dompet',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
