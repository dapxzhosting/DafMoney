import 'package:equatable/equatable.dart';

import '../../transactions/domain/money_transaction.dart';

class WalletTransfer extends Equatable {
  const WalletTransfer({
    required this.id,
    required this.fromWalletId,
    required this.toWalletId,
    required this.amount,
    required this.note,
    required this.date,
  });

  final String id;
  final String fromWalletId;
  final String toWalletId;
  final int amount;
  final String note;
  final DateTime date;

  @override
  List<Object?> get props => [id, fromWalletId, toWalletId, amount, note, date];
}

Map<String, Balance> mergeTransfers(
  Map<String, Balance> base,
  List<WalletTransfer> transfers,
) {
  if (transfers.isEmpty) return base;
  final inc = <String, int>{};
  final exp = <String, int>{};
  base.forEach((k, b) {
    inc[k] = b.income;
    exp[k] = b.expense;
  });
  for (final t in transfers) {
    exp[t.fromWalletId] = (exp[t.fromWalletId] ?? 0) + t.amount;
    inc[t.toWalletId] = (inc[t.toWalletId] ?? 0) + t.amount;
  }
  final keys = {...inc.keys, ...exp.keys};
  return {
    for (final k in keys) k: Balance(income: inc[k] ?? 0, expense: exp[k] ?? 0),
  };
}
