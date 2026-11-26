import 'package:daf_money/features/recurring/domain/recurring_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nextOccurrence', () {
    test('harian dan mingguan', () {
      expect(
        nextOccurrence(DateTime(2026, 1, 31), Frequency.daily, 31),
        DateTime(2026, 2, 1),
      );
      expect(
        nextOccurrence(DateTime(2026, 12, 28), Frequency.weekly, 28),
        DateTime(2027, 1, 4),
      );
    });

    test('bulanan: tanggal 31 menyesuaikan lalu kembali ke 31', () {
      var d = DateTime(2026, 1, 31);
      d = nextOccurrence(d, Frequency.monthly, 31);
      expect(d, DateTime(2026, 2, 28));
      d = nextOccurrence(d, Frequency.monthly, 31);
      expect(d, DateTime(2026, 3, 31));
      d = nextOccurrence(d, Frequency.monthly, 31);
      expect(d, DateTime(2026, 4, 30));
    });

    test('bulanan lintas tahun', () {
      expect(
        nextOccurrence(DateTime(2026, 12, 15), Frequency.monthly, 15),
        DateTime(2027, 1, 15),
      );
    });

    test('tahunan: 29 Februari menjadi 28 Februari di tahun biasa', () {
      expect(
        nextOccurrence(DateTime(2028, 2, 29), Frequency.yearly, 29),
        DateTime(2029, 2, 28),
      );
      expect(
        nextOccurrence(DateTime(2027, 2, 28), Frequency.yearly, 29),
        DateTime(2028, 2, 29),
      );
    });
  });

  group('reminderTime', () {
    test('sehari sebelum jam 09.00 bila masih di masa depan', () {
      expect(
        reminderTime(DateTime(2026, 12, 5), DateTime(2026, 11, 26, 10)),
        DateTime(2026, 12, 4, 9),
      );
    });

    test('lintas bulan dan tahun', () {
      expect(
        reminderTime(DateTime(2027, 1, 1), DateTime(2026, 11, 26)),
        DateTime(2026, 12, 31, 9),
      );
    });

    test('null bila waktunya sudah lewat (harian, atau jatuh tempo hari ini)', () {
      expect(
        reminderTime(DateTime(2026, 11, 27), DateTime(2026, 11, 26, 14)),
        isNull,
      );
      expect(
        reminderTime(DateTime(2026, 11, 26), DateTime(2026, 11, 26, 8)),
        isNull,
      );
    });
  });

  group('dueDates', () {
    test('tidak ada yang jatuh tempo jika jadwal di masa depan', () {
      expect(
        dueDates(
          next: DateTime(2026, 5, 1),
          today: DateTime(2026, 4, 30),
          frequency: Frequency.monthly,
          anchorDay: 1,
        ),
        isEmpty,
      );
    });

    test('mencakup hari ini dan semua yang terlewat', () {
      final d = dueDates(
        next: DateTime(2026, 1, 15),
        today: DateTime(2026, 4, 15),
        frequency: Frequency.monthly,
        anchorDay: 15,
      );
      expect(d, [
        DateTime(2026, 1, 15),
        DateTime(2026, 2, 15),
        DateTime(2026, 3, 15),
        DateTime(2026, 4, 15),
      ]);
    });

    test('dibatasi limit agar tidak membanjiri data', () {
      final d = dueDates(
        next: DateTime(2020, 1, 1),
        today: DateTime(2026, 1, 1),
        frequency: Frequency.daily,
        anchorDay: 1,
        limit: 31,
      );
      expect(d.length, 31);
    });
  });

  group('firstOccurrenceOnOrAfter (perbaikan H1)', () {
    test('mulai di masa depan: tetap tanggal mulai', () {
      expect(
        firstOccurrenceOnOrAfter(
          start: DateTime(2026, 12, 10),
          today: DateTime(2026, 11, 25),
          frequency: Frequency.weekly,
          anchorDay: 10,
        ),
        DateTime(2026, 12, 10),
      );
    });

    test('bulanan sejak Januari diubah ke mingguan: tidak mundur ke Januari', () {
      final next = firstOccurrenceOnOrAfter(
        start: DateTime(2026, 1, 15),
        today: DateTime(2026, 11, 25),
        frequency: Frequency.weekly,
        anchorDay: 15,
      );
      expect(next.isBefore(DateTime(2026, 11, 25)), isFalse);
      expect(next.difference(DateTime(2026, 11, 25)).inDays, lessThan(7));
      final due = dueDates(
        next: next,
        today: DateTime(2026, 11, 25),
        frequency: Frequency.weekly,
        anchorDay: 15,
      );
      expect(due.length, lessThanOrEqualTo(1));
    });

    test('bulanan: ikut tanggal jangkar', () {
      expect(
        firstOccurrenceOnOrAfter(
          start: DateTime(2026, 1, 31),
          today: DateTime(2026, 11, 25),
          frequency: Frequency.monthly,
          anchorDay: 31,
        ),
        DateTime(2026, 11, 30),
      );
    });

    test('jatuh tepat hari ini: dipakai hari ini', () {
      expect(
        firstOccurrenceOnOrAfter(
          start: DateTime(2026, 11, 18),
          today: DateTime(2026, 11, 25),
          frequency: Frequency.weekly,
          anchorDay: 18,
        ),
        DateTime(2026, 11, 25),
      );
    });
  });

  group('nextDateAfterEdit', () {
    final today = DateTime(2026, 11, 25);

    test('tidak ada perubahan jadwal: tidak mengubah nextDate', () {
      expect(
        nextDateAfterEdit(
          start: DateTime(2026, 1, 15),
          oldStart: DateTime(2026, 1, 15),
          oldNext: DateTime(2026, 12, 15),
          oldFrequency: Frequency.monthly,
          frequency: Frequency.monthly,
          today: today,
        ),
        isNull,
      );
    });

    test('bulanan ke mingguan: mulai dari kemunculan berikutnya', () {
      expect(
        nextDateAfterEdit(
          start: DateTime(2026, 1, 15),
          oldStart: DateTime(2026, 1, 15),
          oldNext: DateTime(2026, 12, 15),
          oldFrequency: Frequency.monthly,
          frequency: Frequency.weekly,
          today: today,
        ),
        DateTime(2026, 11, 26),
      );
    });

    test('jadwal lama sudah mencatat hari ini: hari ini dilewati', () {
      expect(
        nextDateAfterEdit(
          start: DateTime(2026, 11, 4),
          oldStart: DateTime(2026, 11, 4),
          oldNext: DateTime(2026, 12, 2),
          oldFrequency: Frequency.weekly,
          frequency: Frequency.daily,
          today: today,
        ),
        DateTime(2026, 11, 26),
      );
    });

    test('mulai dipindah ke hari ini tanpa catatan hari ini: dipakai', () {
      expect(
        nextDateAfterEdit(
          start: DateTime(2026, 11, 25),
          oldStart: DateTime(2026, 11, 5),
          oldNext: DateTime(2026, 12, 5),
          oldFrequency: Frequency.monthly,
          frequency: Frequency.monthly,
          today: today,
        ),
        DateTime(2026, 11, 25),
      );
    });

    test('mulai dipindah ke masa depan: tanggal itu dipakai', () {
      expect(
        nextDateAfterEdit(
          start: DateTime(2027, 2, 1),
          oldStart: DateTime(2026, 1, 15),
          oldNext: DateTime(2026, 12, 15),
          oldFrequency: Frequency.monthly,
          frequency: Frequency.monthly,
          today: today,
        ),
        DateTime(2027, 2, 1),
      );
    });
  });
}
