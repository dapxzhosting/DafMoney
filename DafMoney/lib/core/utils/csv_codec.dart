/// Pembaca/penulis CSV sederhana (RFC 4180): mendukung tanda kutip ganda,
/// koma di dalam kutip, baris baru di dalam kutip, BOM, dan pemisah
/// koma / titik koma / tab (terdeteksi otomatis, karena Excel versi Indonesia
/// memakai titik koma).
abstract class CsvCodec {
  static String encodeField(String s) {
    final needsQuote =
        s.contains(',') ||
        s.contains('"') ||
        s.contains('\n') ||
        s.contains('\r') ||
        s.contains(';');
    return needsQuote ? '"${s.replaceAll('"', '""')}"' : s;
  }

  static String encode(List<List<Object?>> rows) {
    final sb = StringBuffer();
    for (final row in rows) {
      sb.write(row.map((v) => encodeField('${v ?? ''}')).join(','));
      sb.write('\r\n');
    }
    return sb.toString();
  }

  /// Memilih pemisah dari baris pertama di luar tanda kutip.
  static String detectDelimiter(String text) {
    var inQuotes = false;
    final counts = {',': 0, ';': 0, '\t': 0};
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == '"') inQuotes = !inQuotes;
      if (!inQuotes) {
        if (c == '\n') break;
        if (counts.containsKey(c)) counts[c] = counts[c]! + 1;
      }
    }
    var best = ',';
    var max = 0;
    counts.forEach((k, v) {
      if (v > max) {
        max = v;
        best = k;
      }
    });
    return best;
  }

  static List<List<String>> parse(String input) {
    var text = input;
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    final delim = detectDelimiter(text);
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    var fieldStarted = false;

    void endField() {
      row.add(field.toString());
      field.clear();
      fieldStarted = false;
    }

    void endRow() {
      endField();
      // Lewati baris yang benar-benar kosong.
      if (!(row.length == 1 && row.first.trim().isEmpty)) rows.add(row);
      row = <String>[];
    }

    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(c);
        }
        continue;
      }
      if (c == '"' && !fieldStarted) {
        inQuotes = true;
        fieldStarted = true;
      } else if (c == delim) {
        endField();
      } else if (c == '\n') {
        endRow();
      } else if (c == '\r') {
        // CRLF: \n berikutnya yang menutup baris.
        if (i + 1 >= text.length || text[i + 1] != '\n') endRow();
      } else {
        field.write(c);
        fieldStarted = true;
      }
    }
    if (field.isNotEmpty || row.isNotEmpty || fieldStarted) endRow();
    return rows;
  }
}
