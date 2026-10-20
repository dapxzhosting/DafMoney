import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/amount_formatter.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/widgets/app_text_field.dart';
import '../providers/settings_providers.dart';

Future<void> showSettingsSheet(BuildContext context, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => child,
  );
}

class _Frame extends StatelessWidget {
  const _Frame({required this.title, this.subtitle, required this.children});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant, height: 1.45)),
            ],
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class EditNameSheet extends ConsumerStatefulWidget {
  const EditNameSheet({super.key, required this.initial});

  final String initial;

  @override
  ConsumerState<EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends ConsumerState<EditNameSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.initial);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final err =
        await ref.read(settingsActionsProvider).updateName(_name.text.trim());
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      context.showSnack(err, error: true);
      return;
    }
    Navigator.pop(context);
    context.showSnack('Nama diperbarui.');
  }

  @override
  Widget build(BuildContext context) {
    return _Frame(
      title: 'Ubah nama',
      children: [
        Form(
          key: _form,
          child: AppTextField(
            controller: _name,
            label: 'Nama lengkap',
            icon: Icons.person_outline_rounded,
            validator: Validators.name,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(label: 'Simpan', loading: _saving, onPressed: _save),
      ],
    );
  }
}

class InitialBalanceSheet extends ConsumerStatefulWidget {
  const InitialBalanceSheet({super.key, required this.current});

  final int current;

  @override
  ConsumerState<InitialBalanceSheet> createState() =>
      _InitialBalanceSheetState();
}

class _InitialBalanceSheetState extends ConsumerState<InitialBalanceSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.current > 0
        ? ThousandsFormatter.format(widget.current.toString())
        : '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _amount.text.isEmpty ? 0 : (parseAmount(_amount.text) ?? 0);
    setState(() => _saving = true);
    final err = await ref.read(settingsActionsProvider).setInitialBalance(value);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      context.showSnack(err, error: true);
      return;
    }
    Navigator.pop(context);
    context.showSnack('Saldo awal diperbarui.');
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return _Frame(
      title: 'Saldo awal',
      subtitle:
          'Uang yang sudah Anda miliki sebelum mulai mencatat. Jumlah ini ditambahkan ke total saldo di Beranda.',
      children: [
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            ThousandsFormatter(),
          ],
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          decoration: const InputDecoration(prefixText: 'Rp ', hintText: '0'),
        ),
        const SizedBox(height: 20),
        PrimaryButton(label: 'Simpan', loading: _saving, onPressed: _save),
      ],
    );
  }
}

class ChangePasswordSheet extends ConsumerStatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  ConsumerState<ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<ChangePasswordSheet> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final err = await ref
        .read(settingsActionsProvider)
        .changePassword(_current.text, _next.text);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      context.showSnack(err, error: true);
      return;
    }
    Navigator.pop(context);
    context.showSnack('Kata sandi berhasil diubah.');
  }

  @override
  Widget build(BuildContext context) {
    return _Frame(
      title: 'Ubah kata sandi',
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              AppTextField(
                controller: _current,
                label: 'Kata sandi saat ini',
                icon: Icons.lock_outline_rounded,
                obscure: true,
                textInputAction: TextInputAction.next,
                validator: Validators.passwordRequired,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _next,
                label: 'Kata sandi baru',
                icon: Icons.lock_reset_rounded,
                obscure: true,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final base = Validators.newPassword(v);
                  if (base != null) return base;
                  if (v == _current.text) {
                    return 'Harus berbeda dari kata sandi saat ini';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _confirm,
                label: 'Konfirmasi kata sandi baru',
                icon: Icons.lock_reset_rounded,
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: Validators.confirm(() => _next.text),
                onSubmitted: (_) => _save(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(label: 'Simpan', loading: _saving, onPressed: _save),
      ],
    );
  }
}

class DeleteAccountSheet extends ConsumerStatefulWidget {
  const DeleteAccountSheet({super.key});

  @override
  ConsumerState<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<DeleteAccountSheet> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _deleting = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _deleting = true);
    final err =
        await ref.read(settingsActionsProvider).deleteAccount(_password.text);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (err != null) {
      context.showSnack(err, error: true);
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Frame(
      title: 'Hapus akun',
      subtitle:
          'Akun beserta semua transaksi, kategori, dan anggaran akan dihapus PERMANEN dan tidak bisa dikembalikan. Masukkan kata sandi untuk melanjutkan.',
      children: [
        Form(
          key: _form,
          child: AppTextField(
            controller: _password,
            label: 'Kata sandi',
            icon: Icons.lock_outline_rounded,
            obscure: true,
            textInputAction: TextInputAction.done,
            validator: Validators.passwordRequired,
            onSubmitted: (_) => _delete(),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          onPressed: _deleting ? () {} : _delete,
          child: _deleting
              ? SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: cs.onError),
                )
              : const Text('Hapus akun permanen'),
        ),
      ],
    );
  }
}
