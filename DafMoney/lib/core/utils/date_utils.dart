import 'package:equatable/equatable.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

class DateRange extends Equatable {
  const DateRange(this.start, this.end);

  factory DateRange.month(DateTime d) =>
      DateRange(DateTime(d.year, d.month), DateTime(d.year, d.month + 1));

  final DateTime start;
  final DateTime end;

  int get days => end.difference(start).inDays;

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);

  @override
  List<Object?> get props => [start, end];
}
