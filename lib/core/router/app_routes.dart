abstract class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const verifyEmail = '/verify-email';

  static const dashboard = '/dashboard';
  static const transactions = '/transactions';
  static const budgets = '/budgets';
  static const reports = '/reports';
  static const settings = '/settings';

  static const transactionForm = '/transaction-form';
  static const categories = '/categories';

  static const authRoutes = {login, register, forgotPassword};
}
