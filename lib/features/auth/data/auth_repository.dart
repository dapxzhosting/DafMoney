import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      // FirebaseAuthException juga turunan FirebaseException.
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

      // 1) Kirim email verifikasi PERTAMA, sebelum urusan Firestore.
      try {
        await user.sendEmailVerification();
      } catch (_) {}

      // 2) Profil best-effort dengan batas waktu, supaya tidak menggantung.
      try {
        await user.updateDisplayName(cleanName);
        await _createProfile(user, cleanName)
            .timeout(const Duration(seconds: 8));
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

  /// Memuat ulang user dari server. Jika sudah terverifikasi, token ID juga
  /// di-refresh supaya aturan Firestore (email_verified) langsung berlaku.
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

  Future<void> signOut() => _guard(_auth.signOut);

  // ---- Profil di Firestore: users/{uid} ----

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
        await _createProfile(user, user.displayName ?? fallback);
      }
    } catch (_) {
      // Best-effort: jangan menggagalkan login.
    }
  }
}
