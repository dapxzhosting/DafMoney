import '../../../core/utils/date_utils.dart';
import 'money_transaction.dart';

enum TxScope {
  month('Bulan terpilih'),
  last3('3 bulan'),
  last12('12 bulan'),
  all('Semua');

  const TxScope(this.label);

  final String label;

  DateRange get range {
    final n = DateTime.now();
    switch (this) {
      case TxScope.month:
        return DateRange.month(n);
      case TxScope.last3:
        return DateRange(
          DateTime(n.year, n.month - 2),
          DateTime(n.year, n.month + 1),
        );
      case TxScope.last12:
        return DateRange(
          DateTime(n.year, n.month - 11),
          DateTime(n.year, n.month + 1),
        );
      case TxScope.all:
        return DateRange(DateTime(2000), DateTime(n.year + 1));
    }
  }
}

class TxFilter {
  const TxFilter({
    this.categoryIds = const {},
    this.walletIds = const {},
    this.minAmount,
    this.maxAmount,
    this.scope = TxScope.month,
  });

  static const empty = TxFilter();

  final Set<String> categoryIds;
  final Set<String> walletIds;
  final int? minAmount;
  final int? maxAmount;
  final TxScope scope;

  bool get hasAmount => minAmount != null || maxAmount != null;

  int get activeCount =>
      (categoryIds.isEmpty ? 0 : 1) +
      (walletIds.isEmpty ? 0 : 1) +
      (hasAmount ? 1 : 0) +
      (scope == TxScope.month ? 0 : 1);

  bool get isActive => activeCount > 0;

  TxFilter copyWith({
    Set<String>? categoryIds,
    Set<String>? walletIds,
    int? minAmount,
    int? maxAmount,
    bool clearAmount = false,
    TxScope? scope,
  }) {
    return TxFilter(
      categoryIds: categoryIds ?? this.categoryIds,
      walletIds: walletIds ?? this.walletIds,
      minAmount: clearAmount ? null : (minAmount ?? this.minAmount),
      maxAmount: clearAmount ? null : (maxAmount ?? this.maxAmount),
      scope: scope ?? this.scope,
    );
  }

  bool matches(MoneyTransaction t) {
    if (categoryIds.isNotEmpty && !categoryIds.contains(t.categoryId)) {
      return false;
    }
    if (walletIds.isNotEmpty &&
        (t.walletId == null || !walletIds.contains(t.walletId))) {
      return false;
    }
    if (minAmount != null && t.amount < minAmount!) return false;
    if (maxAmount != null && t.amount > maxAmount!) return false;
    return true;
  }
}
