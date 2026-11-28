import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_lock_providers.dart';
import '../../../../core/providers/app_pin_provider.dart';
import '../../../../core/services/app_pin_service.dart';

Widget _pinField(
  TextEditingController c,
  String label, {
  String? error,
  bool autofocus = false,
  ValueChanged<String>? onSubmitted,
}) {
  return TextField(
    controller: c,
    autofocus: autofocus,
    obscureText: true,
    keyboardType: TextInputType.number,
    maxLength: 6,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onSubmitted: onSubmitted,
    decoration: InputDecoration(
      labelText: label,
      errorText: error,
      counterText: '',
      prefixIcon: const Icon(Icons.pin_outlined),
    ),
  );
}

class _PinFrame extends StatelessWidget {
  const _PinFrame({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Atur PIN baru, atau ubah PIN (minta PIN lama dulu).
class SetPinSheet extends ConsumerStatefulWidget {
  const SetPinSheet({super.key});

  @override
  ConsumerState<SetPinSheet> createState() => _SetPinSheetState();
}

class _SetPinSheetState extends ConsumerState<SetPinSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _currentError;
  String? _nextError;
  String? _confirmError;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final hasPin = ref.read(appPinProvider);
    final notifier = ref.read(appPinProvider.notifier);
    String? cErr, nErr, fErr;
    if (hasPin && !notifier.verify(_current.text)) cErr = 'PIN lama salah';
    if (!AppPinService.isValidFormat(_next.text)) {
      nErr = 'PIN harus 4-6 digit angka';
    } else if (_next.text != _confirm.text) {
      fErr = 'Konfirmasi PIN tidak sama';
    }
    if (cErr != null || nErr != null || fErr != null) {
      setState(() {
        _currentError = cErr;
        _nextError = nErr;
        _confirmError = fErr;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    await notifier.setPin(_next.text);
    final lock = ref.read(appLockEnabledProvider.notifier);
    if (!ref.read(appLockEnabledProvider)) await lock.set(true);
    if (nav.canPop()) nav.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(hasPin ? 'PIN diubah.' : 'PIN aplikasi diaktifkan.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final hasPin = ref.watch(appPinProvider);
    return _PinFrame(
      title: hasPin ? 'Ubah PIN' : 'Atur PIN aplikasi',
      subtitle:
          'PIN 4-6 digit ini dipakai membuka DafMoney, selain sidik jari. '
          'PIN hanya tersimpan di perangkat ini dan tidak bisa dipulihkan: '
          'kalau lupa, keluar dari akun lalu masuk lagi.',
      children: [
        if (hasPin) ...[
          _pinField(_current, 'PIN lama', error: _currentError, autofocus: true),
          const SizedBox(height: 12),
        ],
        _pinField(
          _next,
          'PIN baru',
          error: _nextError,
          autofocus: !hasPin,
        ),
        const SizedBox(height: 12),
        _pinField(
          _confirm,
          'Ulangi PIN baru',
          error: _confirmError,
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Simpan PIN'),
        ),
      ],
    );
  }
}

/// Hapus PIN, wajib memasukkan PIN saat ini.
class RemovePinSheet extends ConsumerStatefulWidget {
  const RemovePinSheet({super.key});

  @override
  ConsumerState<RemovePinSheet> createState() => _RemovePinSheetState();
}

class _RemovePinSheetState extends ConsumerState<RemovePinSheet> {
  final _pin = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _remove() async {
    final notifier = ref.read(appPinProvider.notifier);
    if (!notifier.verify(_pin.text)) {
      setState(() => _error = 'PIN salah');
      return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    await notifier.clear();
    if (nav.canPop()) nav.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('PIN dihapus.')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _PinFrame(
      title: 'Hapus PIN',
      subtitle:
          'Setelah PIN dihapus, DafMoney hanya memakai sidik jari atau PIN/pola perangkat.',
      children: [
        _pinField(
          _pin,
          'PIN saat ini',
          error: _error,
          autofocus: true,
          onSubmitted: (_) => _remove(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          onPressed: _busy ? null : _remove,
          child: const Text('Hapus PIN'),
        ),
      ],
    );
  }
}
