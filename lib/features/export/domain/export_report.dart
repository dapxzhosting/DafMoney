import 'package:flutter/painting.dart' show Color;

import '../../../core/models/entry_type.dart';

enum ExportScope {
  month('Bulan'),
  year('Tahun'),
  allYears('Semua'),
  custom('Kustom');

  const ExportScope(this.label);

  final String label;
}

class ExportBucket {
  const ExportBucket(this.label, this.income, this.expense);

  final String label;
  final int income;
  final int expense;

  int get net => income - expense;
}

class ExportCategory {
  const ExportCategory({
    required this.name,
    required this.color,
    required this.total,
    required this.ratio,
  });

  final String name;
  final Color color;
  final int total;

  final double ratio;
}

class ExportEntry {
  const ExportEntry({
    required this.date,
    required this.type,
    required this.categoryName,
    required this.note,
    required this.walletName,
    required this.amount,
  });

  final DateTime date;
  final EntryType type;
  final String categoryName;
  final String note;
  final String walletName;
  final int amount;
}

class ExportReport {
  const ExportReport({
    required this.scope,
    required this.title,
    required this.periodLabel,
    required this.bucketTitle,
    required this.fileSlug,
    required this.generatedAt,
    required this.income,
    required this.expense,
    required this.buckets,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.entries,
    required this.avgDailyExpense,
    required this.savingsRate,
  });

  final ExportScope scope;
  final String title;
  final String periodLabel;
  final String bucketTitle;
  final String fileSlug;
  final DateTime generatedAt;

  final int income;
  final int expense;
  final List<ExportBucket> buckets;
  final List<ExportCategory> expenseCategories;
  final List<ExportCategory> incomeCategories;

  final List<ExportEntry> entries;

  final int avgDailyExpense;

  final double? savingsRate;

  int get net => income - expense;

  int get transactionCount => entries.length;
}
