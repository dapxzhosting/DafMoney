import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

void reportError(Object error, [StackTrace? stack]) {
  if (kDebugMode) {
    debugPrint('$error');
    return;
  }
  try {
    FirebaseCrashlytics.instance
        .recordError(error, stack ?? StackTrace.current, fatal: false)
        .catchError((_) {});
  } catch (_) {}
}
