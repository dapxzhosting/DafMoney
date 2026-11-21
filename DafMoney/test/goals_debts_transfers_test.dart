import 'package:daf_money/features/debts/domain/debt.dart';
import 'package:daf_money/features/goals/domain/savings_goal.dart';
import 'package:daf_money/features/transactions/domain/money_transaction.dart';
import 'package:daf_money/features/transfers/domain/wallet_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SavingsGoal', () {
    SavingsGoal g({int saved = 0, DateTime? deadline}) => SavingsGoal(
      id: 'g',
      name: 'Liburan',
      iconKey: 'flight',
      colorValue: 0xFF3B82F6,
      target: 1000000,
      saved: saved,
      deadline: deadline,
    );

    test('progres dan sisa', () {
      expect(g(saved: 250000).progress, 0.25);
      expect(g(saved: 250000).remaining, 750000);
      expect(g(saved: 2000000).progress, 1.0);
      expect(g(saved: 2000000).remaining, 0);
      expect(g(saved: 1000000).reached, isTrue);
    });

    test('tabungan per bulan menuju tenggat', () {
      final now = DateTime(2026, 1, 10);
      final goal = g(saved: 400000, deadline: DateTime(2026, 4, 10));
      expect(goal.monthlyNeeded(now), 200000); // 600.000 / 3 bulan
      expect(g(deadline: DateTime(2025, 1, 1)).monthlyNeeded(now), isNull);
      expect(g(saved: 1000000, deadline: DateTime(2026, 4, 1)).monthlyNeeded(now), isNull);
    });
  });

  group('Debt', () {
    Debt d({int paid = 0, DateTime? due, DebtKind kind = DebtKind.owe}) => Debt(
      id: 'd',
      person: 'Budi',
      kind: kind,
      amount: 500000,
      paid: paid,
      note: '',
      date: DateTime(2026, 1, 1),
      dueDate: due,
    );

    test('sisa, lunas, dan progres', () {
      expect(d(paid: 200000).remaining, 300000);
      expect(d(paid: 500000).settled, isTrue);
      expect(d(paid: 250000).progress, 0.5);
    });

    test('terlambat hanya bila lewat tanggal dan belum lunas', () {
      final now = DateTime(2026, 3, 10, 15);
      expect(d(due: DateTime(2026, 3, 9)).isOverdue(now), isTrue);
      expect(d(due: DateTime(2026, 3, 10)).isOverdue(now), isFalse);
      expect(d(due: DateTime(2026, 3, 9), paid: 500000).isOverdue(now), isFalse);
      expect(d().isOverdue(now), isFalse);
    });

    test('total belum lunas per arah', () {
      final list = [
        d(paid: 100000),
        d(kind: DebtKind.lend),
        d(paid: 500000),
      ];
      expect(outstanding(list, DebtKind.owe), 400000);
      expect(outstanding(list, DebtKind.lend), 500000);
    });
  });

  group('mergeTransfers', () {
    test('memindahkan saldo antar dompet tanpa mengubah total', () {
      final base = {
        'a': const Balance(income: 1000000, expense: 200000),
        'b': const Balance(income: 0, expense: 0),
      };
      final merged = mergeTransfers(base, [
        WalletTransfer(
          id: 't',
          fromWalletId: 'a',
          toWalletId: 'b',
          amount: 300000,
          note: '',
          date: DateTime(2026, 1, 1),
        ),
      ]);
      expect(merged['a']!.total, 500000);
      expect(merged['b']!.total, 300000);
      final before = base.values.fold<int>(0, (s, b) => s + b.total);
      final after = merged.values.fold<int>(0, (s, b) => s + b.total);
      expect(after, before);
    });

    test('dompet yang belum punya transaksi tetap ikut', () {
      final merged = mergeTransfers(const {}, [
        WalletTransfer(
          id: 't',
          fromWalletId: 'x',
          toWalletId: 'y',
          amount: 100,
          note: '',
          date: DateTime(2026, 1, 1),
        ),
      ]);
      expect(merged['x']!.total, -100);
      expect(merged['y']!.total, 100);
    });
  });
}
