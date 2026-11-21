import 'package:equatable/equatable.dart';

import '../../../core/models/entry_type.dart';
import '../../../core/utils/date_utils.dart';
import '../../transactions/domain/money_transaction.dart';

const challengeMilestones = [3, 7, 14, 30, 60, 100];

class NoSpendChallenge extends Equatable {
  const NoSpendChallenge({
    required this.categoryId,
    required this.startDate,
    required this.targetDays,
    this.bestEver = 0,
  });

  final String categoryId;
  final DateTime startDate;
  final int targetDays;

  final int bestEver;

  @override
  List<Object?> get props => [categoryId, startDate, targetDays, bestEver];

  Map<String, dynamic> toJson() => {
    'c': categoryId,
    's': startDate.toIso8601String(),
    't': targetDays,
    'b': bestEver,
  };

  static NoSpendChallenge? fromJson(Map<String, dynamic> j) {
    final c = j['c'];
    final s = DateTime.tryParse('${j['s']}');
    final t = j['t'];
    if (c is! String || s == null || t is! int) return null;
    final b = j['b'];
    return NoSpendChallenge(
      categoryId: c,
      startDate: dateOnly(s),
      targetDays: t,
      bestEver: b is int ? b : 0,
    );
  }
}

enum DayMark { before, clean, spent }

class ChallengeProgress {
  const ChallengeProgress({
    required this.challenge,
    required this.streak,
    required this.longest,
    required this.best,
    required this.spentToday,
    required this.last7,
  });

  final NoSpendChallenge challenge;

  final int streak;

  final int longest;

  final int best;

  final bool spentToday;

  final List<DayMark> last7;

  int get target => challenge.targetDays;

  bool get completed => streak >= target;

  double get ratio => target == 0 ? 0 : (streak / target).clamp(0.0, 1.0);

  int? get nextMilestone {
    for (final m in challengeMilestones) {
      if (m > streak) return m;
    }
    return null;
  }
}

ChallengeProgress computeChallenge(
  NoSpendChallenge c,
  List<MoneyTransaction> txns, {
  DateTime? now,
}) {
  final today = dateOnly(now ?? DateTime.now());
  final start = dateOnly(c.startDate);

  final spendDays = <DateTime>{
    for (final t in txns)
      if (t.type == EntryType.expense &&
          t.categoryId == c.categoryId &&
          !dateOnly(t.date).isBefore(start))
        dateOnly(t.date),
  };

  var run = 0;
  var longest = 0;
  for (
    var d = start;
    !d.isAfter(today);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    if (spendDays.contains(d)) {
      run = 0;
    } else {
      run++;
      if (run > longest) longest = run;
    }
  }

  final last7 = <DayMark>[
    for (var i = 6; i >= 0; i--)
      () {
        final d = DateTime(today.year, today.month, today.day - i);
        if (d.isBefore(start)) return DayMark.before;
        return spendDays.contains(d) ? DayMark.spent : DayMark.clean;
      }(),
  ];

  return ChallengeProgress(
    challenge: c,
    streak: run,
    longest: longest,
    best: longest > c.bestEver ? longest : c.bestEver,
    spentToday: spendDays.contains(today),
    last7: last7,
  );
}
