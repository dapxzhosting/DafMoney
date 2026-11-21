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

  /// 0..1 (dibatasi), untuk bilah progres.
  double get progress =>
      target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0).toDouble();

  /// Berapa yang perlu ditabung per bulan agar tepat waktu. Null jika tidak
  /// ada tenggat, sudah tercapai, atau tenggat sudah lewat.
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
