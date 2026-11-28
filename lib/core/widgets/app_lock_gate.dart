import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../providers/app_lock_providers.dart';
import '../providers/app_pin_provider.dart';
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
    final hasPin = ref.read(appPinProvider);
    final result = await BiometricService.authenticate(biometricOnly: hasPin);
    _authenticating = false;
    _leftAt = null;
    if (!mounted) return;
    setState(() {
      switch (result) {
        case AuthResult.success:
          _locked = false;
          _message = null;
        case AuthResult.failed:
          _message = hasPin
              ? 'Masukkan PIN atau ketuk "Buka kunci" untuk sidik jari.'
              : 'Verifikasi dibatalkan. Ketuk "Buka kunci" untuk mencoba lagi.';
        case AuthResult.unavailable:
          _message = hasPin
              ? 'Masukkan PIN DafMoney untuk membuka.'
              : 'Kunci layar perangkat tidak aktif. Aktifkan sidik jari atau PIN di pengaturan perangkat, atau keluar dari akun.';
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

    final hasPin = ref.watch(appPinProvider);
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: _LockScreen(
              message: _message,
              onUnlock: _unlock,
              onSignOut: _signOut,
              pinVerify: hasPin
                  ? ref.read(appPinProvider.notifier).verify
                  : null,
              onPinOk: () => setState(() {
                _locked = false;
                _message = null;
              }),
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
    this.pinVerify,
    this.onPinOk,
  });

  final String? message;
  final VoidCallback onUnlock;
  final VoidCallback onSignOut;
  final bool Function(String pin)? pinVerify;
  final VoidCallback? onPinOk;

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
            child: SingleChildScrollView(
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
                  if (pinVerify != null && onPinOk != null) ...[
                    const SizedBox(height: 16),
                    _PinEntry(verify: pinVerify!, onOk: onPinOk!),
                  ],
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
      ),
    );
  }
}

class _PinEntry extends StatefulWidget {
  const _PinEntry({required this.verify, required this.onOk});

  final bool Function(String pin) verify;
  final VoidCallback onOk;

  @override
  State<_PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends State<_PinEntry> {
  static const _maxLen = 6;
  String _pin = '';
  int _fails = 0;
  DateTime? _blockedUntil;
  String? _error;

  bool get _blocked {
    final u = _blockedUntil;
    return u != null && DateTime.now().isBefore(u);
  }

  void _digit(String d) {
    if (_pin.length >= _maxLen) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == _maxLen) _submit();
  }

  void _back() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  void _submit() {
    if (_pin.length < 4) return;
    if (_blocked) {
      final s = _blockedUntil!.difference(DateTime.now()).inSeconds + 1;
      setState(() {
        _pin = '';
        _error = 'Terlalu banyak percobaan. Coba lagi dalam $s detik.';
      });
      return;
    }
    if (widget.verify(_pin)) {
      HapticFeedback.lightImpact();
      widget.onOk();
      return;
    }
    HapticFeedback.heavyImpact();
    _fails++;
    setState(() {
      _pin = '';
      if (_fails >= 5) {
        _fails = 0;
        _blockedUntil = DateTime.now().add(const Duration(seconds: 30));
        _error = 'Terlalu banyak percobaan. Coba lagi dalam 30 detik.';
      } else {
        _error = 'PIN salah.';
      }
    });
  }

  Widget _key(Widget child, VoidCallback? onTap) {
    return SizedBox(
      width: 72,
      height: 56,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Center(child: child),
      ),
    );
  }

  Widget _num(String d) => _key(
    Text(
      d,
      style: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
    ),
    () => _digit(d),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _maxLen; i++)
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? cs.primary : Colors.transparent,
                  border: Border.all(color: cs.outline),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 28,
          child: Center(
            child: Text(
              _error ?? '',
              style: TextStyle(color: cs.error, fontSize: 13),
            ),
          ),
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (final d in row) _num(d)],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _key(
              Icon(Icons.backspace_outlined, color: cs.onSurfaceVariant),
              _back,
            ),
            _num('0'),
            _key(
              Icon(
                Icons.check_circle_rounded,
                color: _pin.length >= 4 ? cs.primary : cs.outlineVariant,
              ),
              _pin.length >= 4 ? _submit : null,
            ),
          ],
        ),
      ],
    );
  }
}
