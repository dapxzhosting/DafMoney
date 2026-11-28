import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart' show errorText;
import '../../../../core/providers/session_providers.dart';
import '../../../../core/utils/amount_formatter.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/app_text_field.dart';
import '../../../data_io/presentation/csv_page.dart' show backupServiceProvider;
import '../../../export/data/export_service.dart';
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
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 16),
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
  late final TextEditingController _name = TextEditingController(
    text: widget.initial,
  );
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final err = await ref
        .read(settingsActionsProvider)
        .updateName(_name.text.trim());
    if (!mounted) return;
    setState(() => _saving = false);
    context.closeSheetWithResult(err);
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
        const SizedBox(height: 16),
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
    final err = await ref
        .read(settingsActionsProvider)
        .setInitialBalance(value);
    if (!mounted) return;
    setState(() => _saving = false);
    context.closeSheetWithResult(err);
    context.showSnack('Saldo awal diperbarui.');
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return _Frame(
      title: 'Saldo awal',
      subtitle: 'Uang yang sudah Anda miliki sebelum mulai mencatat. Jumlah ini ditambahkan ke total saldo di Beranda.',
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
        const SizedBox(height: 16),
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
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Kata sandi berhasil diubah.')),
      );
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
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
        const SizedBox(height: 16),
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
  final _confirmText = TextEditingController();
  bool _deleting = false;
  bool _backingUp = false;

  Future<void> _backup() async {
    final uid = ref.read(uidProvider);
    if (uid == null) return;
    setState(() => _backingUp = true);
    try {
      final bytes = await ref.read(backupServiceProvider).export(uid);
      final d = DateTime.now();
      final stamp =
          '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
      await ExportService.shareBytes(
        bytes: bytes,
        fileName: 'DafMoney_backup_$stamp.json',
        mimeType: 'application/json',
        text: 'Backup DafMoney',
      );
    } catch (e) {
      if (mounted) context.showSnack(errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmText.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final usesPassword = ref.read(authRepositoryProvider).usesPassword;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final cs = Theme.of(context).colorScheme;
    setState(() => _deleting = true);
    final err = await ref
        .read(settingsActionsProvider)
        .deleteAccount(usesPassword ? _password.text : null);
    if (mounted) setState(() => _deleting = false);
    if (err != null) {
      // Alur Google: tutup sheet supaya tidak menggantung, pesan tampil di halaman.
      // Alur kata sandi: sheet tetap terbuka agar bisa mengetik ulang.
      if (!usesPassword && nav.canPop()) nav.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: cs.error,
            content: Text(err, style: TextStyle(color: cs.onError)),
          ),
        );
      return;
    }
    if (nav.canPop()) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Frame(
      title: 'Hapus akun',
      subtitle: ref.read(authRepositoryProvider).usesPassword
          ? 'Akun beserta semua transaksi, kategori, dan anggaran akan dihapus PERMANEN dan tidak bisa dikembalikan. Masukkan kata sandi untuk melanjutkan.'
          : 'Akun beserta semua transaksi, kategori, dan anggaran akan dihapus PERMANEN dan tidak bisa dikembalikan. Anda akan diminta masuk dengan Google sekali lagi untuk konfirmasi.',
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _confirmText,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Ketik HAPUS untuk konfirmasi',
                  prefixIcon: Icon(Icons.warning_amber_rounded),
                ),
                validator: (v) => (v ?? '').trim().toUpperCase() == 'HAPUS'
                    ? null
                    : 'Ketik HAPUS untuk melanjutkan',
              ),
              if (ref.read(authRepositoryProvider).usesPassword) ...[
                const SizedBox(height: 12),
                AppTextField(
                  controller: _password,
                  label: 'Kata sandi',
                  icon: Icons.lock_outline_rounded,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  validator: Validators.passwordRequired,
                  onSubmitted: (_) => _delete(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: (_backingUp || _deleting) ? null : _backup,
          icon: const Icon(Icons.ios_share_rounded),
          label: Text(_backingUp ? 'Menyiapkan backup...' : 'Simpan backup dulu'),
        ),
        const SizedBox(height: 10),
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
                    strokeWidth: 2.5,
                    color: cs.onError,
                  ),
                )
              : const Text('Hapus akun permanen'),
        ),
      ],
    );
  }
}
