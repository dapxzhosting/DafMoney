import 'package:daf_money/features/challenge/domain/no_spend_challenge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoSpendChallenge JSON', () {
    test('hanya memakai field yang diizinkan firestore.rules', () {
      final json = NoSpendChallenge(
        categoryId: 'cat123',
        startDate: DateTime(2026, 11, 21),
        targetDays: 30,
        bestEver: 7,
      ).toJson();

      expect(json.keys.toSet(), {'c', 's', 't', 'b'});
      expect(json['c'], isA<String>());
      expect(json['s'], isA<String>());
      expect(json['t'], isA<int>());
      expect(json['b'], isA<int>());
    });

    test('toJson lalu fromJson menghasilkan data yang sama', () {
      final original = NoSpendChallenge(
        categoryId: 'cat123',
        startDate: DateTime(2026, 11, 21),
        targetDays: 14,
        bestEver: 3,
      );
      final back = NoSpendChallenge.fromJson(original.toJson());
      expect(back, original);
    });

    test('fromJson menolak data rusak', () {
      expect(NoSpendChallenge.fromJson({'c': 1, 's': 'x', 't': 'y'}), isNull);
    });
  });
}
