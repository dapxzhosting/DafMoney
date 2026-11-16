import 'package:go_router/go_router.dart';
import 'package:quick_actions/quick_actions.dart';

import '../models/entry_type.dart';
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
      final type = switch (shortcutType) {
        'action_income' => EntryType.income,
        'action_expense' => EntryType.expense,
        _ => null,
      };
      if (type == null) return;
      router.push('${AppRoutes.transactionForm}?type=${type.name}');
    });
  }
}
