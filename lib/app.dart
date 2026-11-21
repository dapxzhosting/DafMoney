import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/providers/firebase_providers.dart';
import 'core/providers/reminder_provider.dart';
import 'core/providers/session_providers.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/services/quick_actions_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/appearance_provider.dart';
import 'core/theme/theme_provider.dart';
import 'core/providers/quick_entry_provider.dart';
import 'core/services/quick_entry_service.dart';
import 'core/services/quick_templates.dart';
import 'core/widgets/app_lock_gate.dart';
import 'features/recurring/presentation/recurring_providers.dart';

class DafMoneyApp extends ConsumerStatefulWidget {
  const DafMoneyApp({super.key});

  @override
  ConsumerState<DafMoneyApp> createState() => _DafMoneyAppState();
}

class _DafMoneyAppState extends ConsumerState<DafMoneyApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(uidProvider, (prev, next) {
      if (prev != next) _runRecurring();
    });
    ref.listenManual(authTickProvider, (prev, next) => _runRecurring());
    ref.listenManual(uidProvider, (prev, next) {
      if (prev != next) ref.read(reminderProvider.notifier).sync();
    });
    ref.listenManual(uidProvider, (prev, next) {
      if (prev != next) ref.read(quickEntryProvider.notifier).sync();
    });
    Future.microtask(() async {
      try {
        await NotificationService.init();
        await ref.read(reminderProvider.notifier).sync();
      } catch (_) {}
      final router = ref.read(routerProvider);
      QuickActionsService.init(router);
      try {
        await QuickEntryService.init();
        await QuickTemplates.init();
        await ref.read(quickEntryProvider.notifier).sync();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _runRecurring();
  }

  void _runRecurring() {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null || !user.emailVerified) return;
    ref.read(recurringActionsProvider).processDue();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentProvider);
    final amoled = ref.watch(amoledProvider);
    final lightTheme = AppTheme.light(seed: accent);
    final darkTheme = AppTheme.dark(seed: accent, amoled: amoled);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: accent == null && lightDynamic != null
              ? lightTheme.copyWith(colorScheme: lightDynamic)
              : lightTheme,
          darkTheme: accent == null && darkDynamic != null
              ? darkTheme.copyWith(
                  colorScheme: amoled
                      ? darkDynamic.copyWith(surface: Colors.black)
                      : darkDynamic,
                )
              : darkTheme,
          themeMode: themeMode,
          themeAnimationDuration: const Duration(milliseconds: 350),
          themeAnimationCurve: Curves.easeInOut,
          routerConfig: router,
          builder: (context, child) =>
              AppLockGate(child: child ?? const SizedBox.shrink()),
          locale: const Locale('id', 'ID'),
          supportedLocales: const [Locale('id', 'ID'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    );
  }
}
