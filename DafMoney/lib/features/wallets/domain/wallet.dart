import 'package:equatable/equatable.dart';

class Wallet extends Equatable {
  const Wallet({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    required this.initialBalance,
  });

  final String id;
  final String name;
  final String iconKey;
  final int colorValue;
  final int initialBalance;

  @override
  List<Object?> get props => [id, name, iconKey, colorValue, initialBalance];
}
