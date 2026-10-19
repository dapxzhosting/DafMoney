import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/models/entry_type.dart';
import '../domain/category.dart';
import '../domain/category_defaults.dart';

class CategoryRepository {
  CategoryRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _user(uid).collection('categories');

  Category _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return Category(
      id: d.id,
      name: (m['name'] as String?) ?? '',
      type: EntryType.parse(m['type'] as String?),
      iconKey: (m['icon'] as String?) ?? 'more',
      colorValue: (m['color'] as num?)?.toInt() ?? 0xFF78716C,
    );
  }

  Stream<List<Category>> watch(String uid) {
    return _col(uid).snapshots().map((snap) {
      final list = snap.docs.map(_fromDoc).toList();
      list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Future<void> add(
    String uid, {
    required String name,
    required EntryType type,
    required String iconKey,
    required int colorValue,
  }) {
    return _col(uid).add({
      'name': name,
      'type': type.name,
      'icon': iconKey,
      'color': colorValue,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> update(
    String uid,
    String id, {
    required String name,
    required String iconKey,
    required int colorValue,
  }) {
    return _col(uid).doc(id).update({
      'name': name,
      'icon': iconKey,
      'color': colorValue,
    });
  }

  Future<void> delete(String uid, String id) async {
    final used = await _user(uid)
        .collection('transactions')
        .where('categoryId', isEqualTo: id)
        .limit(1)
        .get();
    if (used.docs.isNotEmpty) {
      throw const AppException(
          'Kategori masih dipakai oleh transaksi. Pindahkan atau hapus transaksinya dulu.');
    }
    final budgets = await _user(uid)
        .collection('budgets')
        .where('categoryId', isEqualTo: id)
        .get();
    final batch = _db.batch();
    for (final b in budgets.docs) {
      batch.delete(b.reference);
    }
    batch.delete(_col(uid).doc(id));
    await batch.commit();
  }

  Future<void> seedDefaultsIfEmpty(String uid) async {
    final existing = await _col(uid).limit(1).get();
    if (existing.docs.isNotEmpty) return;
    final batch = _db.batch();
    for (final c in defaultCategories) {
      batch.set(_col(uid).doc(), {
        'name': c.name,
        'type': c.type.name,
        'icon': c.icon,
        'color': c.color,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
