import '../models/entry_type.dart';

/// Hasil membaca satu kalimat singkat, mis. "makan siang 25rb".
class QuickEntry {
  const QuickEntry({required this.note, required this.amount});

  final String note;
  final int amount;
}

final _amountRe = RegExp(
  r'(\d+(?:[.,]\d+)*)\s*(rb|ribu|k|jt|juta)?(?![a-zA-Z])',
  caseSensitive: false,
);

int? _value(String number, String? suffix) {
  final s = suffix?.toLowerCase();
  if (s == null) {
    // Titik/koma dianggap pemisah ribuan: 15.000, 1,250,000.
    return int.tryParse(number.replaceAll(RegExp(r'[.,]'), ''));
  }
  final mult = (s == 'rb' || s == 'ribu' || s == 'k') ? 1000 : 1000000;
  final v = double.tryParse(number.replaceAll(',', '.'));
  if (v == null) return null;
  return (v * mult).round();
}

/// Membaca teks bebas jadi catatan + nominal.
/// Contoh: "makan siang 25rb", "gaji 5jt", "kopi 15.000", "bensin 1,5jt",
/// "25000 parkir". Mengembalikan null bila tidak ada nominal.
QuickEntry? parseQuickEntry(String input) {
  var text = input.trim();
  if (text.isEmpty) return null;
  text = text.replaceAll(RegExp(r'\brp\.?\s*', caseSensitive: false), '');

  final matches = _amountRe.allMatches(text).toList();
  if (matches.isEmpty) return null;

  RegExpMatch? best;
  int bestValue = 0;
  // Nominal dengan akhiran (rb/jt/k) diutamakan; kalau tidak ada, ambil
  // angka terbesar supaya "beli 2 galon 30000" tidak terbaca 2.
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
    'makan', 'minum', 'kopi', 'bakso', 'nasi', 'jajan', 'sarapan', 'snack',
    'resto', 'warung', 'es ', 'teh', 'ayam', 'mie', 'sate', 'roti',
  ],
  'transportasi': [
    'bensin', 'ojek', 'gojek', 'grab', 'parkir', 'tol', 'angkot', 'bus',
    'kereta', 'krl', 'taksi', 'pertamax', 'pertalite', 'servis',
  ],
  'belanja': ['belanja', 'beli', 'baju', 'sepatu', 'tas', 'shopee', 'tokped'],
  'tagihan': [
    'listrik', 'pulsa', 'wifi', 'internet', 'token', 'air ', 'tagihan',
    'cicilan', 'kos', 'sewa', 'paket data',
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

/// Menebak nama kategori bawaan dari catatan. Mengembalikan null bila tidak
/// ada kata kunci yang cocok.
String? guessCategoryName(String note, EntryType type) {
  final n = '${note.toLowerCase()} ';
  final table = type == EntryType.income ? _incomeKeywords : _expenseKeywords;
  for (final e in table.entries) {
    if (e.value.any(n.contains)) return e.key;
  }
  return null;
}
