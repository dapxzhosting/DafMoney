import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/quick_entry_service.dart';
import '../services/quick_templates.dart';
import 'session_providers.dart';
import 'shared_prefs_provider.dart';

const quickEntryEnabledKey = 'quick_entry_enabled';

class QuickEntryNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPrefsProvider).getBool(quickEntryEnabledKey) ?? true;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPrefsProvider).setBool(quickEntryEnabledKey, value);
    await sync();
  }

  Future<void> sync() async {
    try {
      final signedIn = ref.read(uidProvider) != null;
      if (state && signedIn) {
        await QuickEntryService.show();
      } else {
        await QuickEntryService.hide();
      }
      if (signedIn) {
        await QuickTemplates.refresh();
      } else {
        await QuickTemplates.clear();
      }
    } catch (_) {}
  }
}

final quickEntryProvider = NotifierProvider<QuickEntryNotifier, bool>(
  QuickEntryNotifier.new,
);
