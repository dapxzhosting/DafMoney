import 'package:home_widget/home_widget.dart';

import '../utils/formatters.dart';

class WidgetService {
  WidgetService._();

  static const String _androidWidgetName = 'DafMoneyWidgetProvider';

  static Future<void> updateWidgetData({
    required int balance,
    required int remainingBudget,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>(
        'total_balance',
        Fmt.rupiah(balance),
      );
      await HomeWidget.saveWidgetData<String>(
        'remaining_budget',
        Fmt.rupiah(remainingBudget),
      );
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        androidName: _androidWidgetName,
      );
    } catch (_) {}
  }
}
