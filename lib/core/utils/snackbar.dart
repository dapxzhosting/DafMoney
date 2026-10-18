import 'package:flutter/material.dart';

extension SnackX on BuildContext {
  void showSnack(String message, {bool error = false}) {
    final cs = Theme.of(this).colorScheme;
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: error ? cs.error : null,
          content: Text(
            message,
            style: error ? TextStyle(color: cs.onError) : null,
          ),
        ),
      );
  }
}
