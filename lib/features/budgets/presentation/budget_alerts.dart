import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/reminder_provider.dart';
import '../../../core/providers/session_providers.dart';
import '../../../core/services/notification_service.dart';
import '../../categories/presentation/category_style.dart';
import '../../categories/presentation/providers/category_providers.dart';
import 'providers/budget_providers.dart';

class BudgetSnapshot {
  const BudgetSnapshot({
    required this.categoryName,
    required this.limit,
    required this.spent,
  });

  final String categoryName;
  final int limit;
  final int spent;
}

abstract class BudgetAlerts {
  static BudgetSnapshot? capture(
    WidgetRef ref, {
    required String categoryId,
    required DateTime date,
  }) {
    if (!ref.read(budgetAlertsEnabledProvider)) return null;

    final month = ref.read(selectedMonthProvider);
    if (date.year != month.year || date.month != month.month) return null;

    final list = ref.read(budgetProgressProvider).valueOrNull;
    if (list == null) return null;

    for (final p in list) {
      if (p.budget.categoryId == categoryId && p.budget.amount > 0) {
        return BudgetSnapshot(
          categoryName: resolveCategory(
            ref.read(categoryMapProvider),
            categoryId,
          ).name,
          limit: p.budget.amount,
          spent: p.spent,
        );
      }
    }
    return null;
  }

  static Future<void> notifyIfCrossed(BudgetSnapshot before, int delta) async {
    if (delta <= 0) return;
    final b = before.spent / before.limit;
    final a = (before.spent + delta) / before.limit;

    final crossedLimit = b < 1 && a >= 1;
    final crossedWarning = b < 0.8 && a >= 0.8;
    if (!crossedLimit && !crossedWarning) return;

    try {
      await NotificationService.showBudgetWarning(
        categoryName: before.categoryName,
        percentage: (a * 100).round(),
      );
    } catch (_) {}
  }
}
