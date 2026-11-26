import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:daf_money/core/utils/civil_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('civilDateOf', () {
    test('format baru: tengah malam UTC tetap pada tanggalnya', () {
      expect(civilDateOf(DateTime.utc(2026, 12, 1)), DateTime(2026, 12, 1));
      expect(civilDateOf(DateTime.utc(2026, 1, 1)), DateTime(2026, 1, 1));
    });

    test('data lama WIB (tengah malam UTC+7) terbaca pada tanggal yang benar', () {
      expect(
        civilDateOf(DateTime.utc(2026, 11, 30, 17)),
        DateTime(2026, 12, 1),
      );
    });

    test('data lama WITA dan WIT terbaca pada tanggal yang benar', () {
      expect(
        civilDateOf(DateTime.utc(2026, 11, 30, 16)),
        DateTime(2026, 12, 1),
      );
      expect(
        civilDateOf(DateTime.utc(2026, 11, 30, 15)),
        DateTime(2026, 12, 1),
      );
    });

    test('data lama zona barat UTC (mis. UTC-5) tetap pada tanggalnya', () {
      expect(civilDateOf(DateTime.utc(2026, 12, 1, 5)), DateTime(2026, 12, 1));
    });

    test('batas tahun dan bulan', () {
      expect(
        civilDateOf(DateTime.utc(2026, 12, 31, 17)),
        DateTime(2027, 1, 1),
      );
      expect(civilDateOf(DateTime.utc(2028, 2, 28, 17)), DateTime(2028, 2, 29));
    });
  });

  group('civilTimestamp', () {
    test('bolak-balik tidak bergantung pada zona', () {
      for (final d in [
        DateTime(2026, 1, 1),
        DateTime(2026, 2, 28),
        DateTime(2028, 2, 29),
        DateTime(2026, 12, 31),
      ]) {
        final ts = civilTimestamp(d);
        expect(ts.toDate().toUtc(), DateTime.utc(d.year, d.month, d.day));
        expect(civilDateFromTimestamp(ts), d);
      }
    });

    test('civilDateFromValue mengabaikan nilai selain Timestamp', () {
      expect(civilDateFromValue(null), isNull);
      expect(civilDateFromValue('2026-12-01'), isNull);
      expect(
        civilDateFromValue(Timestamp.fromDate(DateTime.utc(2026, 12, 1))),
        DateTime(2026, 12, 1),
      );
    });
  });

  group('batas query', () {
    test('rentang bulan mencakup data lama dan baru', () {
      final start = DateTime(2026, 12, 1);
      final end = DateTime(2027, 1, 1);
      final lower = civilLowerBound(start).toDate().toUtc();
      final upper = civilUpperBound(end).toDate().toUtc();
      final legacyFirst = DateTime.utc(2026, 11, 30, 15);
      final legacyLast = DateTime.utc(2026, 12, 30, 17);
      final newFirst = DateTime.utc(2026, 12, 1);
      final newLast = DateTime.utc(2026, 12, 31);
      for (final t in [legacyFirst, legacyLast, newFirst, newLast]) {
        expect(!t.isBefore(lower) && t.isBefore(upper), isTrue, reason: '$t');
      }
    });
  });
}
