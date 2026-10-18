import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Stream status login / perubahan user. null = belum login.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).userChanges(),
);

/// Dinaikkan setiap kali status verifikasi email diperiksa ulang,
/// supaya router mengevaluasi ulang redirect.
class AuthTick extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final authTickProvider = NotifierProvider<AuthTick, int>(AuthTick.new);
