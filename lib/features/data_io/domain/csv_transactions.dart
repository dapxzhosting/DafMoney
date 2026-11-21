import '../../../core/models/entry_type.dart';
import '../../../core/utils/csv_codec.dart';
import '../../categories/domain/category.dart';
import '../../transactions/domain/money_transaction.dart';
import '../../wallets/domain/wallet.dart';

const csvHeader = [
  'Tanggal',
  'Jenis',
  'Kategori',
  'Dompet',
  'Jumlah',
  'Catatan',
];

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String buildTransactionsCsv(
  List<MoneyTransaction> txns,
  Map<String, Category> cats,
  Map<String, Wallet> wallets,
) {
  final sorted = [...txns]..sort((a, b) => a.date.compareTo(b.date));
  return CsvCodec.encode([
    csvHeader,
    for (final t in sorted)
      [
        _ymd(t.date),
        t.type.label,
        cats[t.categoryId]?.name ?? 'Tanpa kategori',
        wallets[t.walletId]?.name ?? '',
        t.amount,
        t.note,
      ],
  ]);
}

class ImportRow {
  const ImportRow({
    required this.date,
    required this.type,
    required this.categoryName,
    required this.walletName,
    required this.amount,
    required this.note,
  });

  final DateTime date;
  final EntryType type;
  final String categoryName;
  final String? walletName;
  final int amount;
  final String note;

  String get dedupeKey => dedupeKeyOf(date, type, amount, note, categoryName);
}

String dedupeKeyOf(
  DateTime date,
  EntryType type,
  int amount,
  String note,
  String categoryName,
) =>
    '${_ymd(date)}|${type.name}|$amount|${note.trim().toLowerCase()}|${categoryName.trim().toLowerCase()}';

class ImportPreview {
  const ImportPreview({required this.rows, required this.errors});

  final List<ImportRow> rows;

  final List<String> errors;
}

const _maxErrors = 200;

int? _col(List<String> header, List<String> names) {
  for (var i = 0; i < header.length; i++) {
    final h = header[i].trim().toLowerCase();
    if (names.contains(h)) return i;
  }
  return null;
}

DateTime? parseCsvDate(String raw) {
  final s = raw.trim().split(RegExp(r'[ T]')).first;
  final iso = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$').firstMatch(s);
  final dmy = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})$').firstMatch(s);
  int y, m, d;
  if (iso != null) {
    y = int.parse(iso.group(1)!);
    m = int.parse(iso.group(2)!);
    d = int.parse(iso.group(3)!);
  } else if (dmy != null) {
    d = int.parse(dmy.group(1)!);
    m = int.parse(dmy.group(2)!);
    y = int.parse(dmy.group(3)!);
  } else {
    return null;
  }
  if (m < 1 || m > 12 || d < 1 || d > 31 || y < 1970 || y > 2100) return null;
  final dt = DateTime(y, m, d);
  if (dt.month != m || dt.day != d) return null;
  return dt;
}

int? parseCsvAmount(String raw) {
  var s = raw.trim().toLowerCase().replaceAll('rp', '').replaceAll(' ', '');
  if (s.startsWith('-') || s.startsWith('+')) s = s.substring(1);
  if (s.isEmpty) return null;
  int? v;
  if (RegExp(r'^\d+$').hasMatch(s)) {
    v = int.tryParse(s);
  } else if (RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(s)) {
    v = int.tryParse(s.replaceAll(RegExp(r'[.,]'), ''));
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+,\d{1,2}$').hasMatch(s)) {
    v = double.tryParse(s.replaceAll('.', '').replaceAll(',', '.'))?.round();
  } else if (RegExp(r'^\d{1,3}(,\d{3})+\.\d{1,2}$').hasMatch(s)) {
    v = double.tryParse(s.replaceAll(',', ''))?.round();
  } else if (RegExp(r'^\d+[.,]\d{1,2}$').hasMatch(s)) {
    v = double.tryParse(s.replaceAll(',', '.'))?.round();
  }
  if (v == null || v <= 0 || v > 100000000000) return null;
  return v;
}

EntryType? parseCsvType(String raw) {
  final s = raw.trim().toLowerCase();
  if (s.isEmpty) return null;
  if (s.contains('masuk') ||
      s.contains('pemasukan') ||
      s == 'income' ||
      s == 'in' ||
      s == '+') {
    return EntryType.income;
  }
  if (s.contains('keluar') ||
      s.contains('pengeluaran') ||
      s == 'expense' ||
      s == 'out' ||
      s == '-') {
    return EntryType.expense;
  }
  return null;
}

ImportPreview parseTransactionsCsv(String text) {
  final table = CsvCodec.parse(text);
  if (table.isEmpty) {
    return const ImportPreview(rows: [], errors: ['Berkas kosong.']);
  }
  final header = table.first;
  final iDate = _col(header, ['tanggal', 'date', 'tgl']);
  final iType = _col(header, ['jenis', 'type', 'tipe']);
  final iCat = _col(header, ['kategori', 'category']);
  final iWallet = _col(header, ['dompet', 'wallet', 'akun']);
  final iAmount = _col(header, ['jumlah', 'amount', 'nominal']);
  final iNote = _col(header, ['catatan', 'note', 'keterangan', 'deskripsi']);

  final missing = <String>[
    if (iDate == null) 'Tanggal',
    if (iType == null) 'Jenis',
    if (iAmount == null) 'Jumlah',
  ];
  if (missing.isNotEmpty) {
    return ImportPreview(
      rows: const [],
      errors: [
        'Kolom wajib tidak ditemukan: ${missing.join(', ')}. Baris pertama harus berisi judul kolom (Tanggal, Jenis, Kategori, Dompet, Jumlah, Catatan).',
      ],
    );
  }

  String cell(List<String> r, int? i) =>
      (i == null || i >= r.length) ? '' : r[i].trim();

  final rows = <ImportRow>[];
  final errors = <String>[];
  var errorCount = 0;
  void err(String m) {
    errorCount++;
    if (errors.length < _maxErrors) errors.add(m);
  }

  for (var n = 1; n < table.length; n++) {
    final r = table[n];
    final line = n + 1;
    final date = parseCsvDate(cell(r, iDate));
    if (date == null) {
      err('Baris $line: tanggal "${cell(r, iDate)}" tidak valid.');
      continue;
    }
    final type = parseCsvType(cell(r, iType));
    if (type == null) {
      err(
        'Baris $line: jenis "${cell(r, iType)}" harus Pemasukan atau Pengeluaran.',
      );
      continue;
    }
    final amount = parseCsvAmount(cell(r, iAmount));
    if (amount == null) {
      err('Baris $line: jumlah "${cell(r, iAmount)}" tidak valid.');
      continue;
    }
    var cat = cell(r, iCat);
    if (cat.isEmpty) cat = 'Lainnya';
    if (cat.length > 40) cat = cat.substring(0, 40);
    var note = cell(r, iNote);
    if (note.length > 200) note = note.substring(0, 200);
    final wallet = cell(r, iWallet);
    rows.add(
      ImportRow(
        date: date,
        type: type,
        categoryName: cat,
        walletName: wallet.isEmpty
            ? null
            : (wallet.length > 40 ? wallet.substring(0, 40) : wallet),
        amount: amount,
        note: note,
      ),
    );
  }
  if (errorCount > errors.length) {
    errors.add('… dan ${errorCount - errors.length} baris bermasalah lainnya.');
  }
  return ImportPreview(rows: rows, errors: errors);
}
