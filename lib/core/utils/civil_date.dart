import 'package:cloud_firestore/cloud_firestore.dart';

const _zoneWindow = Duration(hours: 14);

DateTime civilDateOf(DateTime instant) {
  final u = instant.toUtc();
  final base = DateTime.utc(u.year, u.month, u.day);
  final day = u.hour >= 12 ? base.add(const Duration(days: 1)) : base;
  return DateTime(day.year, day.month, day.day);
}

DateTime civilDateFromTimestamp(Timestamp ts) => civilDateOf(ts.toDate());

DateTime? civilDateFromValue(Object? v) =>
    v is Timestamp ? civilDateFromTimestamp(v) : null;

Timestamp civilTimestamp(DateTime day) =>
    Timestamp.fromDate(DateTime.utc(day.year, day.month, day.day));

Timestamp civilLowerBound(DateTime day) => Timestamp.fromDate(
  DateTime.utc(day.year, day.month, day.day).subtract(_zoneWindow),
);

Timestamp civilUpperBound(DateTime day) => Timestamp.fromDate(
  DateTime.utc(day.year, day.month, day.day).add(_zoneWindow),
);
