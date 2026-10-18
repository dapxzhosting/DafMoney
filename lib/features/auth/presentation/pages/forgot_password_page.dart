import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/snackbar.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/auth_providers.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_scaffold.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(_email.text);
    if (ok && mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        context.showSnack(next.error.toString(), error: true);
      }
    });
    final loading = ref.watch(authControllerProvider).isLoading;
    final cs = Theme.of(context).colorScheme;

    if (_sent) {
      return AuthScaffold(
        icon: Icons.mark_email_read_rounded,
        title: 'Periksa email Anda',
        subtitle:
            'Jika ${_email.text.trim()} terdaftar, kami telah mengirim tautan untuk mengatur ulang kata sandi. Periksa juga folder spam.',
        children: [
          PrimaryButton(
            label: 'Kembali ke halaman masuk',
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.login),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _sent = false),
            child: const Text('Kirim ke email lain'),
          ),
        ],
      );
    }

    return AuthScaffold(
      canGoBack: true,
      icon: Icons.lock_reset_rounded,
      title: 'Lupa kata sandi?',
      subtitle:
          'Masukkan email akun Anda. Kami akan mengirim tautan untuk membuat kata sandi baru.',
      children: [
        Form(
          key: _form,
          child: AppTextField(
            controller: _email,
            label: 'Email',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            validator: Validators.email,
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
            label: 'Kirim tautan reset', loading: loading, onPressed: _submit),
        const SizedBox(height: 8),
        Icon(Icons.shield_outlined, size: 0, color: cs.primary)
            .animate()
            .fadeIn(),
      ],
    );
  }
}
