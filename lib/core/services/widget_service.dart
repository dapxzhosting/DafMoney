import 'package:home_widget/home_widget.dart';

import '../utils/formatters.dart';

class WidgetService {
  WidgetService._();

  static const String _androidWidgetName = 'DafMoneyWidgetProvider';
  static const String _masked = 'Rp •••';

  static Future<void> updateWidgetData({
    required int balance,
    required int remainingBudget,
    bool hidden = false,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>(
        'total_balance',
        hidden ? _masked : Fmt.rupiah(balance),
      );
      await HomeWidget.saveWidgetData<String>(
        'remaining_budget',
        hidden ? _masked : Fmt.rupiah(remainingBudget),
      );
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        androidName: _androidWidgetName,
      );
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      await HomeWidget.saveWidgetData<String>('total_balance', _masked);
      await HomeWidget.saveWidgetData<String>('remaining_budget', _masked);
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        androidName: _androidWidgetName,
      );
    } catch (_) {}
  }
}
