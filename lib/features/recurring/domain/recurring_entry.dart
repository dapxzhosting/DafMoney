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

  final DateTime nextDate;

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

/// Kemunculan pertama jadwal yang jatuh pada atau setelah [today].
///
/// Dipakai saat jadwal transaksi berulang diubah, supaya `nextDate` tidak
/// dikembalikan ke tanggal mulai lama dan membuat ulang riwayat.
/// Jika [start] masih di masa depan, hasilnya adalah [start] itu sendiri.
DateTime firstOccurrenceOnOrAfter({
  required DateTime start,
  required DateTime today,
  required Frequency frequency,
  required int anchorDay,
}) {
  final end = DateTime(today.year, today.month, today.day);
  var d = DateTime(start.year, start.month, start.day);
  var guard = 0;
  while (d.isBefore(end) && guard < 100000) {
    d = nextOccurrence(d, frequency, anchorDay);
    guard++;
  }
  return d;
}

DateTime? nextDateAfterEdit({
  required DateTime start,
  required DateTime oldStart,
  required DateTime oldNext,
  required Frequency oldFrequency,
  required Frequency frequency,
  required DateTime today,
}) {
  final s = DateTime(start.year, start.month, start.day);
  final t = DateTime(today.year, today.month, today.day);
  final oldS = DateTime(oldStart.year, oldStart.month, oldStart.day);
  if (frequency == oldFrequency && s == oldS) return null;
  var next = firstOccurrenceOnOrAfter(
    start: s,
    today: t,
    frequency: frequency,
    anchorDay: s.day,
  );
  final oldOccursToday =
      !oldS.isAfter(t) &&
      oldNext.isAfter(t) &&
      firstOccurrenceOnOrAfter(
            start: oldS,
            today: t,
            frequency: oldFrequency,
            anchorDay: oldS.day,
          ) ==
          t;
  if (oldOccursToday && next == t) {
    next = nextOccurrence(next, frequency, s.day);
  }
  return next;
}

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
