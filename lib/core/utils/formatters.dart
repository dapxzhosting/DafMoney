import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

abstract class Fmt {
  static final _rupiah = NumberFormat.currency(
    locale: AppConstants.currencyLocale,
    symbol: AppConstants.currencySymbol,
    decimalDigits: 0,
  );

  static final _compact = NumberFormat.compactCurrency(
    locale: AppConstants.currencyLocale,
    symbol: AppConstants.currencySymbol,
    decimalDigits: 1,
  );

  /// 1500000 -> "Rp 1.500.000"
  static String rupiah(num value) => _rupiah.format(value);

  /// 1500000 -> "Rp 1,5 jt"
  static String rupiahCompact(num value) => _compact.format(value);

  /// "Minggu, 18 Okt 2026"
  static String dateLong(DateTime d) =>
      DateFormat('EEEE, d MMM y', AppConstants.currencyLocale).format(d);

  /// "Oktober 2026"
  static String monthYear(DateTime d) =>
      DateFormat('MMMM y', AppConstants.currencyLocale).format(d);
}
