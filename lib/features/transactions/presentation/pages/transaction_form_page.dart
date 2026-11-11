import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/models/entry_type.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/amount_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../categories/presentation/category_style.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../wallets/domain/wallet.dart';
import '../../../wallets/presentation/providers/wallet_providers.dart';
import '../../../wallets/presentation/wallet_style.dart';
import '../../data/receipt_repository.dart';
import '../../domain/money_transaction.dart';
import '../providers/transaction_providers.dart';

class TransactionFormPage extends ConsumerStatefulWidget {
  const TransactionFormPage({super.key, this.initial});

  final MoneyTransaction? initial;

  @override
  ConsumerState<TransactionFormPage> createState() =>
      _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late EntryType _type;
  late DateTime _date;
  String? _categoryId;
  String? _categoryError;
  bool _saving = false;

  // Dompet: selama belum disentuh, transaksi baru memakai dompet pertama.
  String? _walletId;
  bool _walletTouched = false;

  // Foto struk.
  final _picker = ImagePicker();
  Uint8List? _newReceipt;
  bool _removeReceipt = false;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _type = i?.type ?? EntryType.expense;
    _date = i?.date ?? dateOnly(DateTime.now());
    if (i != null) {
      _amount.text = ThousandsFormatter.format(i.amount.toString());
      _note.text = i.note;
      _categoryId = i.categoryId;
      _walletId = i.walletId;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _currentWalletId(List<Wallet> wallets) {
    if (_walletTouched || _editing) return _walletId;
    return wallets.isEmpty ? null : wallets.first.id;
  }

  Future<void> _chooseReceiptSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Ambil foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    await _pickReceipt(source);
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 65,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > ReceiptRepository.maxBytes) {
        context.showSnack(
            'Foto terlalu besar. Coba ambil ulang dengan resolusi lebih kecil.',
            error: true);
        return;
      }
      setState(() {
        _newReceipt = bytes;
        _removeReceipt = false;
      });
    } catch (_) {
      if (!mounted) return;
      context.showSnack('Tidak bisa mengambil foto. Periksa izin kamera atau galeri.',
          error: true);
    }
  }

  void _removeCurrentReceipt() {
    setState(() {
      _newReceipt = null;
      _removeReceipt = true;
    });
  }

  void _viewReceipt(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _save() async {
    final valid = _form.currentState!.validate();
    if (_categoryId == null) {
      setState(() => _categoryError = 'Pilih kategori');
      return;
    }
    if (!valid) return;
    final amount = parseAmount(_amount.text) ?? 0;
    if (amount <= 0) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final actions = ref.read(transactionActionsProvider);
    final wallets = ref.read(walletsProvider).valueOrNull ?? const <Wallet>[];
    final walletId = _currentWalletId(wallets);
    HapticFeedback.mediumImpact();
    final note = _note.text.trim();

    final hadReceipt = _editing && widget.initial!.hasReceipt;
    final keepReceipt = hadReceipt && !_removeReceipt && _newReceipt == null;

    final err = _editing
        ? await actions.update(widget.initial!.id,
            type: _type,
            amount: amount,
            categoryId: _categoryId!,
            note: note,
            date: _date,
            walletId: walletId,
            newReceipt: _newReceipt,
            keepReceipt: keepReceipt,
            hadReceipt: hadReceipt)
        : await actions.add(
            type: _type,
            amount: amount,
            categoryId: _categoryId!,
            note: note,
            date: _date,
            walletId: walletId,
            receipt: _newReceipt);

    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      context.showSnack(err, error: true);
      return;
    }
    context.pop();
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus transaksi?',
      message: 'Transaksi ini akan dihapus permanen.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final err =
        await ref.read(transactionActionsProvider).delete(widget.initial!.id);
    if (!mounted) return;
    if (err != null) {
      context.showSnack(err, error: true);
      return;
    }
    context.pop();
  }

  Widget _buildReceipt(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final hasExisting =
        _editing && widget.initial!.hasReceipt && !_removeReceipt;
    AsyncValue<Uint8List?>? existing;
    if (_newReceipt == null && hasExisting) {
      existing = ref.watch(receiptProvider(widget.initial!.id));
    }
    final Uint8List? bytes = _newReceipt ?? existing?.valueOrNull;

    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            InkWell(
              onTap: () => _viewReceipt(bytes),
              child: Image.memory(
                bytes,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Row(
                children: [
                  _ReceiptAction(
                    icon: Icons.swap_horiz_rounded,
                    tooltip: 'Ganti foto',
                    onTap: _chooseReceiptSource,
                  ),
                  const SizedBox(width: 8),
                  _ReceiptAction(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Hapus foto',
                    onTap: _removeCurrentReceipt,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (existing != null && existing.isLoading) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: const CircularProgressIndicator(),
      );
    }

    final failed = existing != null && existing.hasError;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _chooseReceiptSource,
      child: Container(
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded, color: cs.primary),
            const SizedBox(height: 6),
            Text(
              failed ? 'Foto gagal dimuat. Ketuk untuk ganti.' : 'Tambah foto struk',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fin = context.finance;
    final accent = _type == EntryType.income ? fin.income : fin.expense;
    final cats = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final options = cats.where((c) => c.type == _type).toList();
    final wallets = ref.watch(walletsProvider).valueOrNull ?? const <Wallet>[];
    final selectedWallet = _currentWalletId(wallets);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Ubah transaksi' : 'Tambah transaksi'),
        actions: [
          if (_editing)
            IconButton(
              onPressed: _delete,
              icon: Icon(Icons.delete_outline_rounded, color: cs.error),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: PrimaryButton(
            label: _editing ? 'Simpan perubahan' : 'Simpan transaksi',
            loading: _saving,
            onPressed: _save,
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<EntryType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: EntryType.expense,
                    icon: Icon(Icons.arrow_upward_rounded),
                    label: Text('Pengeluaran'),
                  ),
                  ButtonSegment(
                    value: EntryType.income,
                    icon: Icon(Icons.arrow_downward_rounded),
                    label: Text('Pemasukan'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  final stillValid = cats.any(
                      (c) => c.id == _categoryId && c.type == _type);
                  if (!stillValid) _categoryId = null;
                }),
              ),
            ),
            const SizedBox(height: 24),
            Text('Jumlah',
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandsFormatter(),
              ],
              style: tt.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800, color: accent),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) {
                final n = parseAmount(v ?? '');
                if (n == null || n <= 0) return 'Masukkan jumlah lebih dari 0';
                return null;
              },
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                hintText: '0',
              ),
            ),
            const SizedBox(height: 24),
            Text('Kategori',
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in options)
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 18, color: c.color),
                    label: Text(c.name),
                    selected: _categoryId == c.id,
                    onSelected: (_) => setState(() {
                      _categoryId = c.id;
                      _categoryError = null;
                    }),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Kelola'),
                  onPressed: () => context.push(AppRoutes.categories),
                ),
              ],
            ),
            if (options.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Belum ada kategori ${_type.label.toLowerCase()}. Tambahkan lewat "Kelola".',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            if (_categoryError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_categoryError!,
                    style: tt.bodySmall?.copyWith(color: cs.error)),
              ),
            const SizedBox(height: 24),
            Text('Dompet',
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final w in wallets)
                  ChoiceChip(
                    avatar: Icon(w.icon, size: 18, color: w.color),
                    label: Text(w.name),
                    selected: selectedWallet == w.id,
                    onSelected: (sel) => setState(() {
                      _walletTouched = true;
                      _walletId = sel ? w.id : null;
                    }),
                  ),
                ActionChip(
                  avatar: Icon(
                      wallets.isEmpty ? Icons.add_rounded : Icons.tune_rounded,
                      size: 18),
                  label: Text(wallets.isEmpty ? 'Tambah dompet' : 'Kelola'),
                  onPressed: () => context.push(AppRoutes.wallets),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Tanggal',
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.event_rounded),
                ),
                child: Text(Fmt.dateLong(_date), style: tt.bodyLarge),
              ),
            ),
            const SizedBox(height: 24),
            Text('Catatan (opsional)',
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _note,
              maxLength: 200,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Mis. makan siang bersama tim',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 24),
            Text('Foto struk (opsional)',
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            _buildReceipt(context),
          ],
        ),
      ),
    );
  }
}

class _ReceiptAction extends StatelessWidget {
  const _ReceiptAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
