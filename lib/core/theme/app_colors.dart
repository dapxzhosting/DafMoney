import 'package:flutter/material.dart';

abstract class AppColors {
  static const brand = Color(0xFF0E9F6E);
  static const income = Color(0xFF16A34A);
  static const expense = Color(0xFFE5484D);
  static const warning = Color(0xFFF59E0B);
}

@immutable
class FinanceColors extends ThemeExtension<FinanceColors> {
  const FinanceColors({
    required this.income,
    required this.expense,
    required this.warning,
    required this.surfaceMuted,
  });

  final Color income;
  final Color expense;
  final Color warning;
  final Color surfaceMuted;

  static const light = FinanceColors(
    income: AppColors.income,
    expense: AppColors.expense,
    warning: AppColors.warning,
    surfaceMuted: Color(0xFFF2F5F4),
  );

  static const dark = FinanceColors(
    income: Color(0xFF4ADE80),
    expense: Color(0xFFFF7A80),
    warning: Color(0xFFFBBF24),
    surfaceMuted: Color(0xFF1B2220),
  );

  @override
  FinanceColors copyWith({
    Color? income,
    Color? expense,
    Color? warning,
    Color? surfaceMuted,
  }) =>
      FinanceColors(
        income: income ?? this.income,
        expense: expense ?? this.expense,
        warning: warning ?? this.warning,
        surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      );

  @override
  FinanceColors lerp(ThemeExtension<FinanceColors>? other, double t) {
    if (other is! FinanceColors) return this;
    return FinanceColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
    );
  }
}

extension FinanceColorsX on BuildContext {
  FinanceColors get finance => Theme.of(this).extension<FinanceColors>()!;
}
