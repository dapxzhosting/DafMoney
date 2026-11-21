import 'package:intl/intl.dart';

import '../constants/app_constants.dart';
import 'date_utils.dart';

abstract class Fmt {
  static const _loc = AppConstants.currencyLocale;

  static final _rupiah = NumberFormat.currency(
    locale: _loc,
    symbol: AppConstants.currencySymbol,
    decimalDigits: 0,
  );

  static final _compact = NumberFormat.compactCurrency(
    locale: _loc,
    symbol: AppConstants.currencySymbol,
    decimalDigits: 1,
  );

  static String rupiah(num value) => _rupiah.format(value);

  static String rupiahCompact(num value) => _compact.format(value);

  static String dateLong(DateTime d) =>
      DateFormat('EEEE, d MMM y', _loc).format(d);

  static String dateShort(DateTime d) => DateFormat('d MMM y', _loc).format(d);

  static String monthYear(DateTime d) => DateFormat('MMMM y', _loc).format(d);

  static String monthShort(DateTime d) => DateFormat('MMM', _loc).format(d);

  static String dayHeader(DateTime d) {
    final diff = dateOnly(DateTime.now()).difference(dateOnly(d)).inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    return DateFormat('EEEE, d MMM', _loc).format(d);
  }

  static String percent(double v) => '${(v * 100).round()}%';
}
