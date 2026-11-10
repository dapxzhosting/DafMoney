import 'package:go_router/go_router.dart';
import 'package:quick_actions/quick_actions.dart';

import '../router/app_routes.dart';

class QuickActionsService {
  QuickActionsService._();

  static const QuickActions _actions = QuickActions();

  static void init(GoRouter router) {
    _actions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'action_expense',
        localizedTitle: 'Tambah Pengeluaran',
        icon: 'ic_launcher',
      ),
      const ShortcutItem(
        type: 'action_income',
        localizedTitle: 'Tambah Pemasukan',
        icon: 'ic_launcher',
      ),
    ]);

    _actions.initialize((String shortcutType) {
      if (shortcutType == 'action_expense' || shortcutType == 'action_income') {
        router.push(AppRoutes.transactionForm);
      }
    });
  }
}
