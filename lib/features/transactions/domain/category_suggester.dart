import '../../../core/models/entry_type.dart';
import 'money_transaction.dart';

class CategoryHint {
  const CategoryHint(this.categoryId, this.score, this.confidence);

  final String categoryId;

  final double score;

  final double confidence;
}

const _stopWords = {
  'beli',
  'bayar',
  'untuk',
  'dan',
  'yang',
  'dari',
  'buat',
  'sama',
  'dengan',
  'ini',
  'itu',
  'lagi',
  'sudah',
  'bulan',
  'hari',
  'the',
  'for',
  'and',
};

final _nonAlnum = RegExp(r'[^a-z0-9\s]');
final _spaces = RegExp(r'\s+');
final _digitsOnly = RegExp(r'^\d+$');

Set<String> _tokens(String s) {
  final cleaned = s.toLowerCase().replaceAll(_nonAlnum, ' ');
  return {
    for (final t in cleaned.split(_spaces))
      if (t.length >= 3 && !_stopWords.contains(t) && !_digitsOnly.hasMatch(t))
        t,
  };
}

double _overlap(Set<String> q, Set<String> n) {
  var shared = 0.0;
  for (final a in q) {
    if (n.contains(a)) {
      shared += 1;
      continue;
    }
    for (final b in n) {
      if (a.length >= 4 &&
          b.length >= 4 &&
          (a.startsWith(b) || b.startsWith(a))) {
        shared += 0.7;
        break;
      }
    }
  }
  return shared;
}

List<CategoryHint> suggestCategories({
  required String note,
  required List<MoneyTransaction> history,
  required EntryType type,
  int limit = 3,
}) {
  final q = _tokens(note);
  if (q.isEmpty) return const [];

  final normalized = note.trim().toLowerCase();
  final now = DateTime.now();
  final scores = <String, double>{};

  var seen = 0;
  for (final t in history) {
    if (t.type != type) continue;
    final text = t.note.trim();
    if (text.isEmpty) continue;
    if (++seen > 1500) break;

    final n = _tokens(text);
    if (n.isEmpty) continue;

    var w = _overlap(q, n) / q.length;
    if (w <= 0) continue;
    if (text.toLowerCase() == normalized) w += 1;
    if (now.difference(t.date).inDays <= 30) w *= 1.15;
    scores[t.categoryId] = (scores[t.categoryId] ?? 0) + w;
  }
  if (scores.isEmpty) return const [];

  final total = scores.values.fold<double>(0, (a, b) => a + b);
  final list = [
    for (final e in scores.entries)
      CategoryHint(e.key, e.value, e.value / total),
  ]..sort((a, b) => b.score.compareTo(a.score));

  return list.where((h) => h.score >= 0.5).take(limit).toList();
}
