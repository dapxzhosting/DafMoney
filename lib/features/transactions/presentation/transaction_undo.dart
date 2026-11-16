import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/money_transaction.dart';
import 'providers/transaction_providers.dart';

void _show(
  ScaffoldMessengerState messenger,
  String message, {
  SnackBarAction? action,
  bool error = false,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        duration: Duration(seconds: action == null ? 3 : 5),
        backgroundColor: error ? const Color(0xFFB3261E) : null,
      ),
    );
}

/// Menghapus transaksi lalu menawarkan "Batalkan" selama beberapa detik.
/// Foto struk (jika ada) ikut dikembalikan saat dibatalkan.
///
/// Mengembalikan true jika transaksi berhasil dihapus. [onUndone] dipanggil
/// setelah pembatalan berhasil.
Future<bool> deleteWithUndo(
  BuildContext context,
  WidgetRef ref,
  MoneyTransaction t, {
  VoidCallback? onUndone,
}) async {
  // Ambil semua yang dibutuhkan sebelum await, karena halaman bisa saja
  // sudah tertutup saat proses selesai.
  final messenger = ScaffoldMessenger.of(context);
  final actions = ref.read(transactionActionsProvider);

  final receipt = t.hasReceipt ? await actions.receiptBytes(t.id) : null;
  final err = await actions.delete(t.id);
  if (err != null) {
    _show(messenger, err, error: true);
    return false;
  }

  _show(
    messenger,
    'Transaksi dihapus',
    action: SnackBarAction(
      label: 'Batalkan',
      onPressed: () async {
        final restoreErr = await actions.restore(t, receipt: receipt);
        if (restoreErr != null) {
          _show(messenger, restoreErr, error: true);
          return;
        }
        onUndone?.call();
        _show(messenger, 'Transaksi dikembalikan');
      },
    ),
  );
  return true;
}

/// Menggandakan transaksi dengan tanggal hari ini, dengan opsi "Batalkan".
Future<void> duplicateWithUndo(
  BuildContext context,
  WidgetRef ref,
  MoneyTransaction t,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final actions = ref.read(transactionActionsProvider);
  HapticFeedback.lightImpact();

  final result = await actions.duplicate(t);
  if (result.error != null || result.id == null) {
    _show(messenger, result.error ?? 'Gagal menggandakan transaksi.',
        error: true);
    return;
  }

  final newId = result.id!;
  _show(
    messenger,
    'Transaksi digandakan ke hari ini',
    action: SnackBarAction(
      label: 'Batalkan',
      onPressed: () async {
        final err = await actions.delete(newId);
        if (err != null) _show(messenger, err, error: true);
      },
    ),
  );
}
