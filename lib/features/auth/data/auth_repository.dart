import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/auth_failure.dart';

class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthFailure {
      rethrow;
    } on FirebaseException catch (e) {
      throw AuthFailure.fromCode(e.code);
    } catch (_) {
      throw const AuthFailure('Terjadi kesalahan. Coba lagi.');
    }
  }

  Future<void> signIn({required String email, required String password}) {
    return _guard(() async {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user != null) await _ensureProfile(user);
    });
  }

  /// Ambil kredensial Google lewat pemilih akun native di dalam aplikasi
  /// (tidak membuka browser / website). Mengembalikan null bila dibatalkan.
  Future<AuthCredential?> _googleCredential() async {
    final google = GoogleSignIn(scopes: const ['email']);
    // Paksa pemilih akun muncul lagi (bukan otomatis memakai akun sebelumnya).
    await google.signOut();
    final account = await google.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
  }

  /// Masuk dengan akun Google langsung di aplikasi (native).
  Future<void> signInWithGoogle() {
    return _guard(() async {
      final credential = await _googleCredential();
      if (credential == null) {
        throw const AuthFailure('Masuk dengan Google dibatalkan.');
      }
      final cred = await _auth.signInWithCredential(credential);
      final user = cred.user;
      if (user != null) await _ensureProfile(user);
    });
  }

  /// True bila akun ini punya kata sandi (daftar email). Akun yang hanya
  /// memakai Google tidak punya kata sandi.
  bool get usesPassword =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;

  Future<void> reauthenticateWithGoogle() {
    return _guard(() async {
      final user = _auth.currentUser;
      if (user == null) throw const AuthFailure('Sesi berakhir. Masuk lagi.');
      final credential = await _googleCredential();
      if (credential == null) {
        throw const AuthFailure('Masuk dengan Google dibatalkan.');
      }
      await user.reauthenticateWithCredential(credential);
    });
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) {
    return _guard(() async {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      final cleanName = name.trim();

      try {
        await user.sendEmailVerification();
      } catch (_) {}

      try {
        await user.updateDisplayName(cleanName);
        await _createProfile(
          user,
          cleanName,
        ).timeout(const Duration(seconds: 8));
      } catch (_) {}
    });
  }

  Future<void> sendVerificationEmail() {
    return _guard(() async {
      final user = _auth.currentUser;
      if (user == null) throw const AuthFailure('Sesi berakhir. Masuk lagi.');
      await user.sendEmailVerification();
    });
  }

  Future<bool> refreshVerification() {
    return _guard(() async {
      final user = _auth.currentUser;
      if (user == null) return false;
      await user.reload();
      final fresh = _auth.currentUser;
      if (fresh != null && fresh.emailVerified) {
        await fresh.getIdToken(true);
        return true;
      }
      return false;
    });
  }

  Future<void> sendPasswordReset(String email) {
    return _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));
  }

  Future<void> updateDisplayName(String name) {
    return _guard(() async {
      final user = _auth.currentUser;
      if (user == null) return;
      await user.updateDisplayName(name);
      await user.reload();
    });
  }

  Future<void> _reauth(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthFailure('Sesi berakhir. Masuk lagi.');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } on FirebaseAuthException catch (e) {
      const wrong = {
        'wrong-password',
        'invalid-credential',
        'invalid-login-credentials',
      };
      if (wrong.contains(e.code)) {
        throw const AuthFailure('Kata sandi saat ini salah.');
      }
      rethrow;
    }
  }

  Future<void> reauthenticate(String password) =>
      _guard(() => _reauth(password));

  Future<void> changePassword({required String current, required String next}) {
    return _guard(() async {
      await _reauth(current);
      await _auth.currentUser!.updatePassword(next);
    });
  }

  Future<void> deleteCurrentUser() {
    return _guard(() async => _auth.currentUser?.delete());
  }

  Future<void> signOut() => _guard(_auth.signOut);

  Future<void> _createProfile(User user, String name) {
    return _db.collection('users').doc(user.uid).set({
      'name': name,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _ensureProfile(User user) async {
    try {
      final ref = _db.collection('users').doc(user.uid);
      final snap = await ref.get();
      if (!snap.exists) {
        final fallback = (user.email ?? 'Pengguna').split('@').first;
        var name = (user.displayName ?? '').trim();
        if (name.isEmpty) name = fallback;
        if (name.length > 60) name = name.substring(0, 60);
        await _createProfile(user, name);
      }
    } catch (_) {}
  }
}
