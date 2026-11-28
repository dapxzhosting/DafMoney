import 'package:equatable/equatable.dart';

class SavingsGoal extends Equatable {
  const SavingsGoal({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    required this.target,
    required this.saved,
    this.deadline,
  });

  final String id;
  final String name;
  final String iconKey;
  final int colorValue;
  final int target;
  final int saved;
  final DateTime? deadline;

  int get remaining => (target - saved).clamp(0, target).toInt();

  bool get reached => saved >= target;

  double get progress =>
      target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0).toDouble();

  /// Kebutuhan tabungan sesuai sisa waktu: per bulan bila tenggat >= 30 hari,
  /// per minggu bila 7-29 hari, per hari bila kurang dari seminggu.
  ({int amount, String unit})? savingPace(DateTime now) {
    final d = deadline;
    if (d == null || reached || !d.isAfter(now)) return null;
    final days = d.difference(now).inDays;
    if (days >= 30) {
      final v = monthlyNeeded(now);
      return v == null ? null : (amount: v, unit: 'bulan');
    }
    if (days >= 7) {
      final weeks = (days / 7).ceil();
      return (amount: (remaining / weeks).ceil(), unit: 'minggu');
    }
    final left = days < 1 ? 1 : days;
    return (amount: (remaining / left).ceil(), unit: 'hari');
  }

  int? monthlyNeeded(DateTime now) {
    final d = deadline;
    if (d == null || reached) return null;
    final months = (d.year - now.year) * 12 + (d.month - now.month);
    if (!d.isAfter(now)) return null;
    final m = months < 1 ? 1 : months;
    return (remaining / m).ceil();
  }

  @override
  List<Object?> get props => [
    id,
    name,
    iconKey,
    colorValue,
    target,
    saved,
    deadline,
  ];
}
