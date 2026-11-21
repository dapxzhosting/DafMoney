import 'package:flutter/painting.dart' show Color;

import '../../../core/models/entry_type.dart';

/// Cakupan periode laporan yang bisa diekspor.
enum ExportScope {
  month('Bulan'),
  year('Tahun'),
  allYears('Semua'),
  custom('Kustom');

  const ExportScope(this.label);

  final String label;
}

/// Satu batang pada ringkasan (satu minggu, satu bulan, atau satu tahun).
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

  /// Bagian dari total jenisnya (0..1).
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

/// Semua angka yang dibutuhkan PDF maupun kartu gambar, sudah dihitung.
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

  /// Urut dari tanggal terlama ke terbaru.
  final List<ExportEntry> entries;

  final int avgDailyExpense;

  /// null bila tidak ada pemasukan.
  final double? savingsRate;

  int get net => income - expense;

  int get transactionCount => entries.length;
}
