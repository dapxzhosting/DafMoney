import 'package:equatable/equatable.dart';

import '../../../core/models/entry_type.dart';

enum Frequency {
  daily('Harian'),
  weekly('Mingguan'),
  monthly('Bulanan'),
  yearly('Tahunan');

  const Frequency(this.label);

  final String label;

  static Frequency parse(String? s) => Frequency.values.firstWhere(
    (f) => f.name == s,
    orElse: () => Frequency.monthly,
  );
}

/// Aturan transaksi yang dicatat otomatis (gaji, langganan, cicilan, dst.).
class RecurringEntry extends Equatable {
  const RecurringEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.note,
    required this.frequency,
    required this.startDate,
    required this.nextDate,
    required this.anchorDay,
    required this.active,
    this.walletId,
  });

  final String id;
  final EntryType type;
  final int amount;
  final String categoryId;
  final String note;
  final String? walletId;
  final Frequency frequency;
  final DateTime startDate;

  /// Tanggal kemunculan berikutnya yang belum dicatat.
  final DateTime nextDate;

  /// Tanggal (1-31) acuan untuk jadwal bulanan/tahunan, supaya "31 Januari"
  /// tetap kembali ke tanggal 31 setelah melewati Februari.
  final int anchorDay;
  final bool active;

  @override
  List<Object?> get props => [
    id,
    type,
    amount,
    categoryId,
    note,
    walletId,
    frequency,
    startDate,
    nextDate,
    anchorDay,
    active,
  ];
}

/// Kemunculan setelah [from]. Murni (tanpa efek samping) agar mudah dites.
DateTime nextOccurrence(DateTime from, Frequency f, int anchorDay) {
  switch (f) {
    case Frequency.daily:
      return DateTime(from.year, from.month, from.day + 1);
    case Frequency.weekly:
      return DateTime(from.year, from.month, from.day + 7);
    case Frequency.monthly:
      final first = DateTime(from.year, from.month + 1, 1);
      return DateTime(first.year, first.month, _clampDay(first, anchorDay));
    case Frequency.yearly:
      final first = DateTime(from.year + 1, from.month, 1);
      return DateTime(first.year, first.month, _clampDay(first, anchorDay));
  }
}

int _clampDay(DateTime firstOfMonth, int day) {
  final last = DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0).day;
  return day > last ? last : day;
}

/// Semua tanggal jatuh tempo dari [next] sampai [today] (inklusif), maksimal
/// [limit] agar aturan yang lama tidak terbuka tidak membanjiri data.
List<DateTime> dueDates({
  required DateTime next,
  required DateTime today,
  required Frequency frequency,
  required int anchorDay,
  int limit = 31,
}) {
  final out = <DateTime>[];
  var d = DateTime(next.year, next.month, next.day);
  final end = DateTime(today.year, today.month, today.day);
  while (!d.isAfter(end) && out.length < limit) {
    out.add(d);
    d = nextOccurrence(d, frequency, anchorDay);
  }
  return out;
}
