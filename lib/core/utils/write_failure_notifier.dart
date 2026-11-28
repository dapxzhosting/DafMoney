import 'package:flutter/material.dart';

import '../error/app_exception.dart' show errorText;

final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

DateTime? _lastShown;

void notifyWriteFailure(Object error) {
  final now = DateTime.now();
  final last = _lastShown;
  if (last != null && now.difference(last) < const Duration(seconds: 20)) {
    return;
  }
  _lastShown = now;
  final messenger = rootMessengerKey.currentState;
  if (messenger == null) return;
  final cs = Theme.of(messenger.context).colorScheme;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        backgroundColor: cs.error,
        content: Text(
          'Perubahan terakhir gagal disimpan ke server dan bisa hilang. '
          '${errorText(error)} Coba ulangi.',
          style: TextStyle(color: cs.onError),
        ),
      ),
    );
}
