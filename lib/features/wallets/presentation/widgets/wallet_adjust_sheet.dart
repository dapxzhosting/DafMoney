import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/amount_formatter.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../../core/widgets/form_bits.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/wallet.dart';
import '../providers/wallet_providers.dart';

/// Tambahkan uang selisih ke dompet. [balance] = saldo dompet saat ini di aplikasi.
Future<void> showWalletAdjustSheet(
  BuildContext context, {
  required Wallet wallet,
  required int balance,
}) => showFormSheet(
  context,
  WalletAdjustSheet(wallet: wallet, balance: balance),
);

enum _Mode { selisih, saldo }

class WalletAdjustSheet extends ConsumerStatefulWidget {
  const WalletAdjustSheet({
    super.key,
    required this.wallet,
    required this.balance,
  });

  final Wallet wallet;
  final int balance;

  @override
  ConsumerState<WalletAdjustSheet> createState() => _WalletAdjustSheetState();
}

class _WalletAdjustSheetState extends ConsumerState<WalletAdjustSheet> {
  final _amount = TextEditingController();
  _Mode _mode = _Mode.selisih;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// Jumlah uang yang akan ditambahkan ke dompet (null bila isian belum valid).
  int? get _diff {
    final v = parseAmount(_amount.text);
    if (v == null || v <= 0) return null;
    return _mode == _Mode.selisih ? v : v - widget.balance;
  }

  Future<void> _save() async {
    final v = parseAmount(_amount.text);
    String? error;
    if (v == null || v <= 0) {
      error = 'Nominal wajib diisi.';
    } else if (_mode == _Mode.saldo && v <= widget.balance) {
      error =
          'Saldo sebenarnya harus lebih besar dari saldo di aplikasi (${Fmt.rupiah(widget.balance)}).';
    }
    setState(() => _error = error);
    if (error != null) return;

    final diff = _diff!;
    final w = widget.wallet;
    setState(() => _saving = true);
    // Selisih ditambahkan ke saldo dompet tanpa dihitung sebagai pemasukan,
    // jadi laporan pemasukan/pengeluaran tidak terganggu.
    final err = await ref
        .read(walletActionsProvider)
        .update(
          w.id,
          name: w.name,
          iconKey: w.iconKey,
          colorValue: w.colorValue,
          initialBalance: w.initialBalance + diff,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      context.showSnack(err, error: true);
      return;
    }
    Navigator.pop(context);
    context.showSnack('${Fmt.rupiah(diff)} ditambahkan ke ${w.name}.');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final diff = _diff;
    return SheetBody(
      title: 'Tambah selisih • ${widget.wallet.name}',
      children: [
        Text(
          'Saldo di aplikasi: ${Fmt.rupiah(widget.balance)}',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SegmentedButton<_Mode>(
          segments: const [
            ButtonSegment(value: _Mode.selisih, label: Text('Jumlah selisih')),
            ButtonSegment(
              value: _Mode.saldo,
              label: Text('Saldo sebenarnya'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() {
            _mode = s.first;
            _error = null;
          }),
        ),
        const SizedBox(height: 16),
        AmountField(
          controller: _amount,
          autofocus: true,
          label: _mode == _Mode.selisih
              ? 'Uang selisih yang ditambahkan'
              : 'Saldo sebenarnya di dompet',
          errorText: _error,
          onChanged: (_) => setState(() => _error = null),
        ),
        if (diff != null && diff > 0) ...[
          const SizedBox(height: 12),
          Text(
            'Ditambahkan: ${Fmt.rupiah(diff)}  →  saldo jadi ${Fmt.rupiah(widget.balance + diff)}',
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
        ],
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Tambahkan ke dompet',
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
