import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage>
    with WidgetsBindingObserver {
  static const _cooldownSeconds = 60;
  static const _pollEvery = 4;

  Timer? _timer;
  int _cooldown = _cooldownSeconds; // email pertama baru saja dikirim
  int _ticks = 0;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_cooldown > 0) setState(() => _cooldown--);
      _ticks++;
      if (_ticks % _pollEvery == 0) _check(silent: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pengguna kembali dari aplikasi email.
    if (state == AppLifecycleState.resumed) _check(silent: true);
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    setState(() => _checking = true);
    final ok = await ref.read(authControllerProvider.notifier).checkVerified();
    if (!mounted) return;
    setState(() => _checking = false);
    if (!ok && !silent) {
      context.showSnack(
        'Email belum terverifikasi. Klik tautan di email Anda (cek folder spam).',
        error: true,
      );
    }
    // Jika ok -> router otomatis pindah ke dashboard.
  }

  Future<void> _resend() async {
    final ok =
        await ref.read(authControllerProvider.notifier).resendVerification();
    if (!mounted) return;
    if (ok) {
      setState(() => _cooldown = _cooldownSeconds);
      context.showSnack('Email verifikasi dikirim ulang.');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        context.showSnack(next.error.toString(), error: true);
      }
    });

    final email = ref.watch(authStateProvider).valueOrNull?.email ?? '';
    final sending = ref.watch(authControllerProvider).isLoading;

    return AuthScaffold(
      icon: Icons.mark_email_unread_rounded,
      title: 'Verifikasi email Anda',
      subtitle:
          'Kami mengirim tautan verifikasi ke $email. Buka email Anda, klik tautannya, lalu kembali ke sini. Halaman ini akan otomatis lanjut.',
      children: [
        PrimaryButton(
          label: 'Saya sudah verifikasi',
          loading: _checking,
          onPressed: () => _check(),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: (_cooldown > 0 || sending) ? null : _resend,
          child: Text(
            _cooldown > 0
                ? 'Kirim ulang email (${_cooldown}d)'
                : 'Kirim ulang email',
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          child: const Text('Gunakan akun lain'),
        ),
      ],
    );
  }
}
