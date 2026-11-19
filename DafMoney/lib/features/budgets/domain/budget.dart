import 'package:equatable/equatable.dart';

class Budget extends Equatable {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.month,
  });

  final String id;
  final String categoryId;
  final int amount;
  final String month;

  @override
  List<Object?> get props => [id, categoryId, amount, month];
}

enum BudgetStatus { safe, warning, over }

class BudgetProgress {
  const BudgetProgress(this.budget, this.spent);

  final Budget budget;
  final int spent;

  double get ratio => budget.amount <= 0 ? 0 : spent / budget.amount;
  int get remaining => budget.amount - spent;

  BudgetStatus get status {
    if (ratio >= 1) return BudgetStatus.over;
    if (ratio >= 0.8) return BudgetStatus.warning;
    return BudgetStatus.safe;
  }
}
