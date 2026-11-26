import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/entry_type.dart';
import '../../../core/utils/civil_date.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_style.dart';
import '../../transactions/domain/money_transaction.dart';
import '../../wallets/domain/wallet.dart';
import '../domain/csv_transactions.dart';
import 'commit_util.dart';

class ImportPlan {
  const ImportPlan({
    required this.toImport,
    required this.duplicates,
    required this.newCategories,
    required this.newWallets,
  });

  final List<ImportRow> toImport;
  final int duplicates;

  final Set<String> newCategories;
  final Set<String> newWallets;
}

String _catKey(EntryType type, String name) =>
    '${type.name}|${name.trim().toLowerCase()}';

ImportPlan planImport({
  required List<ImportRow> rows,
  required List<MoneyTransaction> existing,
  required Map<String, Category> categories,
  required List<Wallet> wallets,
}) {
  final remaining = <String, int>{};
  for (final t in existing) {
    final k = dedupeKeyOf(
      t.date,
      t.type,
      t.amount,
      t.note,
      categories[t.categoryId]?.name ?? 'Tanpa kategori',
    );
    remaining[k] = (remaining[k] ?? 0) + 1;
  }
  final catKeys = {for (final c in categories.values) _catKey(c.type, c.name)};
  final walletNames = {for (final w in wallets) w.name.trim().toLowerCase()};

  final toImport = <ImportRow>[];
  var dups = 0;
  final newCats = <String>{};
  final newWallets = <String>{};
  for (final r in rows) {
    final left = remaining[r.dedupeKey] ?? 0;
    if (left > 0) {
      remaining[r.dedupeKey] = left - 1;
      dups++;
      continue;
    }
    toImport.add(r);
    final ck = _catKey(r.type, r.categoryName);
    if (!catKeys.contains(ck)) newCats.add(ck);
    final w = r.walletName;
    if (w != null && !walletNames.contains(w.trim().toLowerCase())) {
      newWallets.add(w.trim().toLowerCase());
    }
  }
  return ImportPlan(
    toImport: toImport,
    duplicates: dups,
    newCategories: newCats,
    newWallets: newWallets,
  );
}

class ImportService {
  ImportService(this._db);

  final FirebaseFirestore _db;

  Future<int> run(
    String uid, {
    required ImportPlan plan,
    required Map<String, Category> categories,
    required List<Wallet> wallets,
    void Function(int done, int total)? onProgress,
  }) async {
    final user = _db.collection('users').doc(uid);
    final catCol = user.collection('categories');
    final walletCol = user.collection('wallets');
    final txCol = user.collection('transactions');

    final catIds = <String, String>{
      for (final c in categories.values) _catKey(c.type, c.name): c.id,
    };
    final walletIds = <String, String>{
      for (final w in wallets) w.name.trim().toLowerCase(): w.id,
    };

    final setup = _db.batch();
    var setupOps = 0;
    for (final r in plan.toImport) {
      final ck = _catKey(r.type, r.categoryName);
      if (!catIds.containsKey(ck)) {
        final ref = catCol.doc();
        catIds[ck] = ref.id;
        setup.set(ref, {
          'name': r.categoryName,
          'type': r.type.name,
          'icon': 'more',
          'color': CategoryPalette.colors.last,
          'createdAt': FieldValue.serverTimestamp(),
        });
        setupOps++;
      }
      final w = r.walletName?.trim();
      if (w != null && !walletIds.containsKey(w.toLowerCase())) {
        final ref = walletCol.doc();
        walletIds[w.toLowerCase()] = ref.id;
        setup.set(ref, {
          'name': w,
          'icon': 'payments',
          'color': CategoryPalette.colors[5],
          'initialBalance': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        setupOps++;
      }
    }
    if (setupOps > 450) {
      throw StateError(
        'Terlalu banyak kategori/dompet baru (>450). Rapikan nama di berkas lalu coba lagi.',
      );
    }
    if (setupOps > 0) await commitBatch(setup);

    var done = 0;
    final total = plan.toImport.length;
    for (var i = 0; i < total; i += 400) {
      final chunk = plan.toImport.sublist(i, i + 400 > total ? total : i + 400);
      final batch = _db.batch();
      for (final r in chunk) {
        final walletId = r.walletName == null
            ? null
            : walletIds[r.walletName!.trim().toLowerCase()];
        batch.set(txCol.doc(), {
          'type': r.type.name,
          'amount': r.amount,
          'categoryId': catIds[_catKey(r.type, r.categoryName)],
          'note': r.note,
          'date': civilTimestamp(r.date),
          'createdAt': FieldValue.serverTimestamp(),
          if (walletId != null) 'walletId': walletId,
        });
      }
      await commitBatch(batch);
      done += chunk.length;
      onProgress?.call(done, total);
    }
    return done;
  }
}
