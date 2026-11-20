import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/form_bits.dart';
import '../../../core/widgets/primary_button.dart';
import '../../transactions/domain/money_transaction.dart';
import '../../wallets/domain/wallet.dart';
import '../../wallets/presentation/providers/wallet_providers.dart';
import 'transfer_providers.dart';

Future<void> showTransferSheet(BuildContext context) =>
    showFormSheet(context, const TransferSheet());

class TransferSheet extends ConsumerStatefulWidget {
  const TransferSheet({super.key});

  @override
  ConsumerState<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<TransferSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _from;
  String? _to;
  DateTime _date = dateOnly(DateTime.now());
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _swap() => setState(() {
    final t = _from;
    _from = _to;
    _to = t;
  });

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    String? error;
    if (_from == null || _to == null) {
      error = 'Pilih dompet asal dan tujuan.';
    } else if (_from == _to) {
      error = 'Dompet asal dan tujuan harus berbeda.';
    } else if (amount == null || amount <= 0) {
      error = 'Nominal wajib diisi.';
    }
    setState(() => _error = error);
    if (error != null) return;
    setState(() => _saving = true);
    final err = await ref
        .read(transferActionsProvider)
        .add(
          fromWalletId: _from!,
          toWalletId: _to!,
          amount: amount!,
          note: _note.text.trim(),
          date: _date,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      context.showSnack(err, error: true);
      return;
    }
    Navigator.pop(context);
    context.showSnack('Transfer ${Fmt.rupiah(amount)} dicatat.');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wallets = ref.watch(walletsProvider).valueOrNull ?? const <Wallet>[];
    final totals =
        ref.watch(walletTotalsProvider).valueOrNull ??
        const <String, Balance>{};
    int balanceOf(Wallet w) => w.initialBalance + (totals[w.id]?.total ?? 0);

    if (wallets.length < 2) {
      return const SheetBody(
        title: 'Transfer antar dompet',
        children: [
          Text('Buat minimal dua dompet dulu untuk memindahkan saldo.'),
          SizedBox(height: 24),
        ],
      );
    }

    DropdownButtonFormField<String> picker(
      String label,
      String? value,
      ValueChanged<String?> onChanged,
    ) {
      return DropdownButtonFormField<String>(
        key: ValueKey('$label-$value'),
        initialValue: wallets.any((w) => w.id == value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final w in wallets)
            DropdownMenuItem(
              value: w.id,
              child: Text('${w.name} · ${Fmt.rupiah(balanceOf(w))}'),
            ),
        ],
        onChanged: onChanged,
      );
    }

    return SheetBody(
      title: 'Transfer antar dompet',
      children: [
        picker('Dari dompet', _from, (v) => setState(() => _from = v)),
        Align(
          alignment: Alignment.center,
          child: IconButton.filledTonal(
            tooltip: 'Tukar',
            onPressed: _swap,
            icon: const Icon(Icons.swap_vert_rounded),
          ),
        ),
        picker('Ke dompet', _to, (v) => setState(() => _to = v)),
        const SizedBox(height: 16),
        AmountField(controller: _amount),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Catatan (opsional)',
            hintText: 'Mis. Isi saldo DANA',
          ),
        ),
        DateField(
          label: 'Tanggal',
          value: _date,
          onChanged: (d) => setState(() => _date = dateOnly(d ?? _date)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: cs.error)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            label: 'Pindahkan',
            loading: _saving,
            onPressed: _save,
          ),
        ),
      ],
    );
  }
}
