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
