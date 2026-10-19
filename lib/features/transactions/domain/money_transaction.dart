import 'package:equatable/equatable.dart';

import '../../../core/models/entry_type.dart';

class MoneyTransaction extends Equatable {
  const MoneyTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.note,
    required this.date,
    required this.createdAt,
  });

  final String id;
  final EntryType type;
  final int amount;
  final String categoryId;
  final String note;
  final DateTime date;
  final DateTime createdAt;

  @override
  List<Object?> get props =>
      [id, type, amount, categoryId, note, date, createdAt];
}

class Balance {
  const Balance({required this.income, required this.expense});

  static const zero = Balance(income: 0, expense: 0);

  final int income;
  final int expense;

  int get total => income - expense;
}
