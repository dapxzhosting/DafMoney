import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/budgets/presentation/pages/budgets_page.dart';
import '../../features/categories/presentation/pages/categories_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/reports/presentation/reports_page.dart';
import '../../features/transactions/domain/money_transaction.dart';
import '../models/entry_type.dart';
import '../../features/transactions/presentation/pages/transaction_form_page.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/wallets/presentation/pages/wallets_page.dart';
import '../../features/splash/presentation/splash_page.dart';
import '../../features/challenge/presentation/challenge_page.dart';
import '../../features/data_io/presentation/csv_page.dart';
import '../../features/debts/presentation/debts_page.dart';
import '../../features/goals/presentation/goals_page.dart';
import '../../features/recurring/presentation/recurring_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../providers/firebase_providers.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/animated_branch_container.dart';
import '../widgets/main_shell.dart';
import 'app_routes.dart';

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(authTickProvider, (_, __) => notifyListeners());
    _ref.listen(onboardingDoneProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final loc = state.matchedLocation;
    final auth = _ref.read(authStateProvider);

    if (auth.isLoading && !auth.hasValue) {
      return loc == AppRoutes.splash ? null : AppRoutes.splash;
    }

    final user = _ref.read(firebaseAuthProvider).currentUser;

    if (user == null) {
      return AppRoutes.authRoutes.contains(loc) ? null : AppRoutes.login;
    }

    if (!user.emailVerified) {
      return loc == AppRoutes.verifyEmail ? null : AppRoutes.verifyEmail;
    }

    // Pengguna yang belum pernah melihat onboarding diarahkan ke sana dulu.
    if (!_ref.read(onboardingDoneProvider)) {
      return loc == AppRoutes.onboarding ? null : AppRoutes.onboarding;
    }

    if (loc == AppRoutes.onboarding ||
        loc == AppRoutes.splash ||
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
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashPage()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginPage()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingPage(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (_, __) => const VerifyEmailPage(),
      ),
      GoRoute(
        path: AppRoutes.transactionForm,
        pageBuilder: (_, state) => smoothPage(
          state,
          TransactionFormPage(
            initial: state.extra as MoneyTransaction?,
            initialType: EntryType.values
                .asNameMap()[state.uri.queryParameters['type']],
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.categories,
        pageBuilder: (_, s) => smoothPage(s, const CategoriesPage()),
      ),
      GoRoute(
        path: AppRoutes.challenge,
        pageBuilder: (_, s) => smoothPage(s, const ChallengePage()),
      ),
      GoRoute(
        path: AppRoutes.recurring,
        pageBuilder: (_, s) => smoothPage(s, const RecurringPage()),
      ),
      GoRoute(
        path: AppRoutes.goals,
        pageBuilder: (_, s) => smoothPage(s, const GoalsPage()),
      ),
      GoRoute(
        path: AppRoutes.debts,
        pageBuilder: (_, s) => smoothPage(s, const DebtsPage()),
      ),
      GoRoute(
        path: AppRoutes.csv,
        pageBuilder: (_, s) => smoothPage(s, const CsvPage()),
      ),
      GoRoute(
        path: AppRoutes.walletManager,
        pageBuilder: (_, s) => smoothPage(s, const WalletsPage()),
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (_, s) => smoothPage(s, const SettingsPage()),
      ),
      StatefulShellRoute(
        builder: (_, __, shell) => MainShell(shell: shell),
        navigatorContainerBuilder: (context, shell, children) =>
            FadeThroughBranches(
              currentIndex: shell.currentIndex,
              children: children,
            ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (_, __) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.transactions,
                builder: (_, __) => const TransactionsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.wallets,
                builder: (_, __) => const WalletsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.budgets,
                builder: (_, __) => const BudgetsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reports,
                builder: (_, __) => const ReportsPage(),
              ),
            ],
          ),
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
