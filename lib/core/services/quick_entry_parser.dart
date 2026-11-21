import '../models/entry_type.dart';

class QuickEntry {
  const QuickEntry({required this.note, required this.amount});

  final String note;
  final int amount;
}

final _amountRe = RegExp(
  r'(\d+(?:[.,]\d+)*)\s*(rb|ribu|k|jt|juta)?(?![a-zA-Z])',
  caseSensitive: false,
);

const _minPlainAmount = 1000;

int? _value(String number, String? suffix) {
  final s = suffix?.toLowerCase();
  if (s == null) {
    return int.tryParse(number.replaceAll(RegExp(r'[.,]'), ''));
  }
  final mult = (s == 'rb' || s == 'ribu' || s == 'k') ? 1000 : 1000000;
  final v = double.tryParse(number.replaceAll(',', '.'));
  if (v == null) return null;
  return (v * mult).round();
}

QuickEntry? parseQuickEntry(String input) {
  var text = input.trim();
  if (text.isEmpty) return null;
  text = text.replaceAll(RegExp(r'\brp\.?\s*', caseSensitive: false), '');

  final matches = _amountRe.allMatches(text).where((m) {
    if (m.group(2) != null) return true;
    return (_value(m.group(1)!, null) ?? 0) >= _minPlainAmount;
  }).toList();
  if (matches.isEmpty) return null;

  RegExpMatch? best;
  int bestValue = 0;
  final withSuffix = matches.where((m) => m.group(2) != null).toList();
  if (withSuffix.isNotEmpty) {
    best = withSuffix.last;
    bestValue = _value(best.group(1)!, best.group(2)) ?? 0;
  } else {
    for (final m in matches) {
      final v = _value(m.group(1)!, null) ?? 0;
      if (v >= bestValue) {
        best = m;
        bestValue = v;
      }
    }
  }
  if (best == null || bestValue <= 0) return null;

  var note = (text.substring(0, best.start) + text.substring(best.end))
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (note.isEmpty) note = 'Transaksi cepat';
  note = note[0].toUpperCase() + note.substring(1);
  return QuickEntry(note: note, amount: bestValue);
}

const _expenseKeywords = <String, List<String>>{
  'makanan & minuman': [
    'makan',
    'minum',
    'kopi',
    'bakso',
    'nasi',
    'jajan',
    'sarapan',
    'snack',
    'resto',
    'warung',
    'es ',
    'teh',
    'ayam',
    'mie',
    'sate',
    'roti',
  ],
  'transportasi': [
    'bensin',
    'ojek',
    'gojek',
    'grab',
    'parkir',
    'tol',
    'angkot',
    'bus',
    'kereta',
    'krl',
    'taksi',
    'pertamax',
    'pertalite',
    'servis',
  ],
  'belanja': ['belanja', 'beli', 'baju', 'sepatu', 'tas', 'shopee', 'tokped'],
  'tagihan': [
    'listrik',
    'pulsa',
    'wifi',
    'internet',
    'token',
    'air ',
    'tagihan',
    'cicilan',
    'kos',
    'sewa',
    'paket data',
  ],
  'hiburan': ['nonton', 'game', 'bioskop', 'netflix', 'spotify', 'konser'],
  'kesehatan': ['obat', 'dokter', 'klinik', 'apotek', 'vitamin', 'rumah sakit'],
  'pendidikan': ['buku', 'kursus', 'sekolah', 'spp', 'kuliah', 'les '],
};

const _incomeKeywords = <String, List<String>>{
  'gaji': ['gaji', 'salary', 'honor'],
  'bonus': ['bonus', 'thr', 'hadiah'],
  'investasi': ['invest', 'dividen', 'saham', 'bunga', 'reksa'],
};

String? guessCategoryName(String note, EntryType type) {
  final n = '${note.toLowerCase()} ';
  final table = type == EntryType.income ? _incomeKeywords : _expenseKeywords;
  for (final e in table.entries) {
    if (e.value.any(n.contains)) return e.key;
  }
  return null;
}

String summarizeSharedText(String text) {
  final t = text.trim();
  if (t.isEmpty) return '';
  final rpRe = RegExp(r'rp\.?\s*([\d.,]+)', caseSensitive: false);

  int? best;
  for (final m in rpRe.allMatches(t)) {
    var raw = m.group(1)!;
    raw = raw.replaceFirst(RegExp(r'[.,]\d{1,2}$'), '');
    final v = int.tryParse(raw.replaceAll(RegExp(r'[.,]'), ''));
    if (v != null && (best == null || v > best)) best = v;
  }
  if (best == null) {
    return t.length > 60 ? t.substring(0, 60) : t;
  }

  var note = t
      .split('\n')
      .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '')
      .replaceAll(rpRe, '')
      .replaceAll(RegExp(r'\d'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (note.length > 28) note = note.substring(0, 28).trim();
  if (note.isEmpty) note = 'Transaksi';
  return '$note $best';
}

EntryType guessSharedType(String text) {
  final t = text.toLowerCase();
  const incomeWords = ['diterima', 'dana masuk', 'menerima', 'uang masuk'];
  return incomeWords.any(t.contains) ? EntryType.income : EntryType.expense;
}
