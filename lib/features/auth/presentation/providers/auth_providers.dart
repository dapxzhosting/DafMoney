import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  ),
);

/// State = status operasi terakhir (loading / error). Navigasi ditangani
/// router lewat redirect, jadi controller tidak perlu memanggil context.go.
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }

  Future<bool> signIn(String email, String password) =>
      _run(() => _repo.signIn(email: email, password: password));

  Future<bool> register(String name, String email, String password) =>
      _run(() => _repo.register(name: name, email: email, password: password));

  Future<bool> resendVerification() => _run(_repo.sendVerificationEmail);

  Future<bool> sendPasswordReset(String email) =>
      _run(() => _repo.sendPasswordReset(email));

  Future<void> signOut() => _run(_repo.signOut);

  /// Pengecekan diam-diam (polling) — tidak mengubah state loading/error.
  Future<bool> checkVerified() async {
    try {
      final ok = await _repo.refreshVerification();
      if (ok) ref.read(authTickProvider.notifier).bump();
      return ok;
    } catch (_) {
      return false;
    }
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
