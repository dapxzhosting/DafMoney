import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Menyimpan berkas sementara lalu membuka lembar bagikan sistem. Dari sana
/// pengguna bisa mengirim ke aplikasi lain atau menyimpan ke berkas / galeri.
abstract class ExportService {
  static Future<void> shareBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? text,
    Rect? origin,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType, name: fileName)],
      text: text,
      subject: text,
      sharePositionOrigin: origin,
    );
  }
}
