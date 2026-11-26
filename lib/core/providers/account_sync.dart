import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/transactions/data/transaction_repository.dart'
    show writeSafe;
import '../services/error_reporter.dart';
import 'firebase_providers.dart';

Map<String, dynamic>? loadedUserData(Ref ref, String uid) =>
    ref.read(userDocStreamProvider(uid)).valueOrNull?.data();

Future<void> syncToAccount(
  FirebaseFirestore db,
  String uid,
  Map<String, Object?> data,
) async {
  try {
    await writeSafe(
      () => db.collection('users').doc(uid).set(data, SetOptions(merge: true)),
    );
<<<<<<< HEAD
  } catch (_) {}
=======
  } catch (e, st) {
    reportError(e, st);
  }
>>>>>>> 1f1b1b0 (Update DafMoney)
}

bool isSettledServerSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) =>
    !snap.metadata.isFromCache && !snap.metadata.hasPendingWrites;
