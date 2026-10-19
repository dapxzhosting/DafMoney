import 'package:equatable/equatable.dart';

import '../../../core/models/entry_type.dart';

class Category extends Equatable {
  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.iconKey,
    required this.colorValue,
  });

  final String id;
  final String name;
  final EntryType type;
  final String iconKey;
  final int colorValue;

  @override
  List<Object?> get props => [id, name, type, iconKey, colorValue];
}
