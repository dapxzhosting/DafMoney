import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/services/quick_actions_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

class DafMoneyApp extends ConsumerStatefulWidget {
  const DafMoneyApp({super.key});

  @override
  ConsumerState<DafMoneyApp> createState() => _DafMoneyAppState();
}

class _DafMoneyAppState extends ConsumerState<DafMoneyApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      NotificationService.init();
      NotificationService.scheduleDailyReminder();
      final router = ref.read(routerProvider);
      QuickActionsService.init(router);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 350),
      themeAnimationCurve: Curves.easeInOut,
      routerConfig: router,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
