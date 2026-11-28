import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_providers.dart';
import 'session_providers.dart';

final pendingSyncProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(false);
  final db = ref.watch(firestoreProvider);
  return db
      .collection('users')
      .doc(uid)
      .collection('transactions')
      .snapshots(includeMetadataChanges: true)
      .map((snap) => snap.metadata.hasPendingWrites)
      .distinct();
});

final pendingSyncAnyProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(false);
  final db = ref.watch(firestoreProvider);
  const names = [
    'transactions',
    'wallets',
    'budgets',
    'categories',
    'recurring',
    'transfers',
    'goals',
    'debts',
  ];
  final pending = <String, bool>{};
  final ctrl = StreamController<bool>();
  final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
  for (final n in names) {
    subs.add(
      db
          .collection('users')
          .doc(uid)
          .collection(n)
          .snapshots(includeMetadataChanges: true)
          .listen((snap) {
            pending[n] = snap.metadata.hasPendingWrites;
            if (!ctrl.isClosed) ctrl.add(pending.values.any((v) => v));
          }, onError: (_) {}),
    );
  }
  ref.onDispose(() {
    for (final s in subs) {
      s.cancel();
    }
    ctrl.close();
  });
  return ctrl.stream.distinct();
});
