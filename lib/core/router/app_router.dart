import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/splash/presentation/splash_page.dart';
import '../providers/firebase_providers.dart';
import '../widgets/main_shell.dart';
import '../widgets/placeholder_page.dart';
import 'app_routes.dart';

/// Menjembatani Riverpod -> GoRouter: router di-refresh saat status auth berubah.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(authTickProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final loc = state.matchedLocation;
    final auth = _ref.read(authStateProvider);

    // Firebase belum menjawab -> tahan di splash.
    if (auth.isLoading && !auth.hasValue) {
      return loc == AppRoutes.splash ? null : AppRoutes.splash;
    }

    // Baca langsung dari currentUser agar emailVerified selalu terbaru.
    final user = _ref.read(firebaseAuthProvider).currentUser;

    // 1) Belum login
    if (user == null) {
      return AppRoutes.authRoutes.contains(loc) ? null : AppRoutes.login;
    }

    // 2) Sudah login tapi email belum diverifikasi
    if (!user.emailVerified) {
      return loc == AppRoutes.verifyEmail ? null : AppRoutes.verifyEmail;
    }

    // 3) Login + terverifikasi: jangan biarkan di halaman auth / splash
    if (loc == AppRoutes.splash ||
        loc == AppRoutes.verifyEmail ||
        AppRoutes.authRoutes.contains(loc)) {
      return AppRoutes.dashboard;
    }

    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: refresh.redirect,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashPage(),
      ),

      // ---- Auth ----
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (_, __) => const VerifyEmailPage(),
      ),

      // ---- Aplikasi utama: bottom navigation dengan state per tab ----
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.dashboard,
              builder: (_, __) => const PlaceholderPage(
                title: 'Beranda',
                icon: Icons.space_dashboard_rounded,
                note: 'Dashboard dibuat di Tahap 3',
                showAppBar: false,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.transactions,
              builder: (_, __) => const PlaceholderPage(
                title: 'Transaksi',
                icon: Icons.receipt_long_rounded,
                note: 'Dibuat di Tahap 4',
                showAppBar: false,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.budgets,
              builder: (_, __) => const PlaceholderPage(
                title: 'Anggaran',
                icon: Icons.account_balance_wallet_rounded,
                note: 'Dibuat di Tahap 5',
                showAppBar: false,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.reports,
              builder: (_, __) => const PlaceholderPage(
                title: 'Laporan',
                icon: Icons.insert_chart_rounded,
                note: 'Dibuat di Tahap 6',
                showAppBar: false,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.settings,
              builder: (_, __) => const SettingsPage(),
            ),
          ]),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });

  return router;
});
