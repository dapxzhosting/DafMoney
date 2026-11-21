import 'package:equatable/equatable.dart';

enum DebtKind {
  owe('Utang saya', 'Saya berutang ke'),
  lend('Piutang', 'Orang yang berutang');

  const DebtKind(this.label, this.personLabel);

  final String label;
  final String personLabel;

  static DebtKind parse(String? s) =>
      s == 'lend' ? DebtKind.lend : DebtKind.owe;
}

class Debt extends Equatable {
  const Debt({
    required this.id,
    required this.person,
    required this.kind,
    required this.amount,
    required this.paid,
    required this.note,
    required this.date,
    this.dueDate,
  });

  final String id;
  final String person;
  final DebtKind kind;
  final int amount;
  final int paid;
  final String note;
  final DateTime date;
  final DateTime? dueDate;

  int get remaining => (amount - paid).clamp(0, amount).toInt();

  bool get settled => paid >= amount;

  double get progress =>
      amount <= 0 ? 0 : (paid / amount).clamp(0.0, 1.0).toDouble();

  bool isOverdue(DateTime now) {
    final d = dueDate;
    if (d == null || settled) return false;
    final today = DateTime(now.year, now.month, now.day);
    return d.isBefore(today);
  }

  @override
  List<Object?> get props => [
    id,
    person,
    kind,
    amount,
    paid,
    note,
    date,
    dueDate,
  ];
}

int outstanding(Iterable<Debt> debts, DebtKind kind) => debts
    .where((d) => d.kind == kind)
    .fold<int>(0, (sum, d) => sum + d.remaining);
