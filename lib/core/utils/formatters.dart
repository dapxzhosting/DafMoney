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

  /// 1500000 -> "Rp 1.500.000"
  static String rupiah(num value) => _rupiah.format(value);

  /// 1500000 -> "Rp 1,5 jt"
  static String rupiahCompact(num value) => _compact.format(value);

  /// "Minggu, 18 Okt 2026"
  static String dateLong(DateTime d) =>
      DateFormat('EEEE, d MMM y', _loc).format(d);

  /// "18 Okt 2026"
  static String dateShort(DateTime d) => DateFormat('d MMM y', _loc).format(d);

  /// "Oktober 2026"
  static String monthYear(DateTime d) => DateFormat('MMMM y', _loc).format(d);

  /// "Okt"
  static String monthShort(DateTime d) => DateFormat('MMM', _loc).format(d);

  /// "Hari ini" / "Kemarin" / "Senin, 5 Okt"
  static String dayHeader(DateTime d) {
    final diff = dateOnly(DateTime.now()).difference(dateOnly(d)).inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    return DateFormat('EEEE, d MMM', _loc).format(d);
  }

  static String percent(double v) => '${(v * 100).round()}%';
}
