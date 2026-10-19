import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/models/entry_type.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/providers/session_providers.dart';
import '../../../../core/providers/shared_prefs_provider.dart';
import '../../data/category_repository.dart';
import '../../domain/category.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(firestoreProvider)),
);

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const <Category>[]);
  return ref.watch(categoryRepositoryProvider).watch(uid);
});

final categoryMapProvider = Provider<Map<String, Category>>((ref) {
  final list = ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
  return {for (final c in list) c.id: c};
});

/// Mengisi kategori bawaan sekali untuk pengguna baru.
final categorySeedProvider = FutureProvider<void>((ref) async {
  final uid = ref.watch(uidProvider);
  if (uid == null) return;
  final prefs = ref.read(sharedPrefsProvider);
  final key = 'categories_seeded_$uid';
  if (prefs.getBool(key) ?? false) return;
  await ref.read(categoryRepositoryProvider).seedDefaultsIfEmpty(uid);
  await prefs.setBool(key, true);
});

class CategoryActions {
  CategoryActions(this._ref);

  final Ref _ref;

  String get _uid =>
      _ref.read(uidProvider) ?? (throw const AppException('Sesi berakhir. Masuk lagi.'));

  CategoryRepository get _repo => _ref.read(categoryRepositoryProvider);

  Future<String?> add({
    required String name,
    required EntryType type,
    required String iconKey,
    required int colorValue,
  }) =>
      runGuarded(() => _repo.add(_uid,
          name: name, type: type, iconKey: iconKey, colorValue: colorValue));

  Future<String?> update(
    String id, {
    required String name,
    required String iconKey,
    required int colorValue,
  }) =>
      runGuarded(() => _repo.update(_uid, id,
          name: name, iconKey: iconKey, colorValue: colorValue));

  Future<String?> delete(String id) =>
      runGuarded(() => _repo.delete(_uid, id));
}

final categoryActionsProvider =
    Provider<CategoryActions>((ref) => CategoryActions(ref));
