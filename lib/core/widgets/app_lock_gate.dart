import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../providers/app_lock_providers.dart';
import '../providers/firebase_providers.dart';
import '../providers/session_providers.dart';
import '../providers/shared_prefs_provider.dart';
import '../services/biometric_service.dart';
import '../services/screen_security_service.dart';
import '../services/widget_service.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  late bool _locked;
  bool _authenticating = false;
  DateTime? _leftAt;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = _initialLocked();
    ScreenSecurityService.setSecure(_locked);
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  bool _initialLocked() {
    final uid = ref.read(uidProvider) ??
        ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return false;
    return ref
            .read(sharedPrefsProvider)
            .getBool('${AppConstants.appLockKey}_$uid') ??
        false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (!_authenticating) _leftAt ??= DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    final left = _leftAt;
    _leftAt = null;
    if (left == null || _authenticating || _locked) return;
    if (!ref.read(appLockEnabledProvider)) return;
    final grace = ref.read(appLockGraceProvider);
    if (DateTime.now().difference(left).inSeconds >= grace) {
      setState(() {
        _locked = true;
        _message = null;
      });
      _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    _authenticating = true;
    final result = await BiometricService.authenticate();
    _authenticating = false;
    _leftAt = null;
    if (!mounted) return;
    setState(() {
      switch (result) {
        case AuthResult.success:
          _locked = false;
          _message = null;
        case AuthResult.failed:
          _message =
          'Verifikasi dibatalkan. Ketuk "Buka kunci" untuk mencoba lagi.';
        case AuthResult.unavailable:
          _message = 'Kunci layar perangkat tidak aktif. Aktifkan sidik jari atau PIN di pengaturan perangkat, atau keluar dari akun.';
      }
    });
  }

  Future<void> _signOut() async {
    await ref
        .read(appLockEnabledProvider.notifier)
        .set(false, syncRemote: false);
    await ref.read(firebaseAuthProvider).signOut();
    await WidgetService.clear();
    if (mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      appLockEnabledProvider,
          (prev, next) => ScreenSecurityService.setSecure(next),
    );
    ref.listen<bool>(appLockEnabledProvider, (prev, next) {
      if (!next && _locked) setState(() => _locked = false);
      if (!(prev ?? false) &&
          next &&
          !_locked &&
          ref.read(appLockEnabledProvider.notifier).changedByRemote) {
        setState(() {
          _locked = true;
          _message = null;
        });
        _unlock();
      }
    });

    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: _LockScreen(
              message: _message,
              onUnlock: _unlock,
              onSignOut: _signOut,
            ),
          ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({
    required this.message,
    required this.onUnlock,
    required this.onSignOut,
  });

  final String? message;
  final VoidCallback onUnlock;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Material(
        color: cs.surface,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.6, end: 1),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    builder: (_, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 44,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'DafMoney terkunci',
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message ?? 'Verifikasi untuk melihat data keuangan Anda.',
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 240,
                    child: FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onUnlock();
                      },
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: const Text('Buka kunci'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onSignOut,
                    child: const Text('Keluar dari akun'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}