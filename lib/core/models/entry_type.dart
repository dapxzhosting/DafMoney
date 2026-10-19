enum EntryType {
  income,
  expense;

  String get label => this == income ? 'Pemasukan' : 'Pengeluaran';

  static EntryType parse(String? s) =>
      s == 'income' ? EntryType.income : EntryType.expense;
}
