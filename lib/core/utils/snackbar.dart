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

extension SheetX on BuildContext {
  void closeSheetWithResult(String? err) {
    final nav = Navigator.of(this);
    final messenger = ScaffoldMessenger.of(this);
    final cs = Theme.of(this).colorScheme;
    if (nav.canPop()) nav.pop();
    if (err == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: cs.error,
          content: Text(err, style: TextStyle(color: cs.onError)),
        ),
      );
  }
}
