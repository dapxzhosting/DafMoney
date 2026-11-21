import 'dart:ui' show DartPluginRegistrant;

import 'package:home_widget/home_widget.dart';

import '../models/entry_type.dart';
import 'quick_entry_saver.dart';
import 'quick_entry_service.dart';

/// Template favorit (widget memakai 3 pertama, popup memakai 6): catatan pengeluaran yang paling
/// sering dipakai. Ketuk salah satunya di widget -> langsung tersimpan
/// (nominal & kategori dari riwayat) tanpa membuka app.
class QuickTemplates {
  QuickTemplates._();

  static const _widgetName = 'DafMoneyWidgetProvider';
  static const slots = 6;

  /// Daftarkan penangan ketukan tombol widget (jalan di latar belakang).
  static Future<void> init() async {
    await HomeWidget.registerInteractivityCallback(
      quickWidgetBackgroundCallback,
    );
  }

  /// Hitung ulang template dari riwayat lalu perbarui widget.
  static Future<void> refresh() async {
    try {
      final top = await QuickEntrySaver.topNotes(
        EntryType.expense,
        limit: slots,
      );
      for (var i = 1; i <= slots; i++) {
        final n = i <= top.length ? top[i - 1] : null;
        await HomeWidget.saveWidgetData<String>('tpl_$i', n?.note ?? '');
        await HomeWidget.saveWidgetData<String>('tpl_${i}_label', n?.label ?? '');
      }
      await HomeWidget.updateWidget(name: _widgetName, androidName: _widgetName);
    } catch (_) {}
  }

  /// Kosongkan template (mis. saat logout).
  static Future<void> clear() async {
    try {
      for (var i = 1; i <= slots; i++) {
        await HomeWidget.saveWidgetData<String>('tpl_$i', '');
        await HomeWidget.saveWidgetData<String>('tpl_${i}_label', '');
      }
      await HomeWidget.updateWidget(name: _widgetName, androidName: _widgetName);
    } catch (_) {}
  }
}

/// Dipanggil saat tombol template di widget diketuk, app boleh tertutup.
@pragma('vm:entry-point')
Future<void> quickWidgetBackgroundCallback(Uri? uri) async {
  DartPluginRegistrant.ensureInitialized();
  if (uri == null) return;

  // Dari popup "Catat cepat": simpan teks apa adanya (jenis ikut pilihan).
  if (uri.host == 'save') {
    final type = EntryType.parse(uri.queryParameters['type']);
    final text = uri.queryParameters['text'] ?? '';
    final result = await QuickEntrySaver.save(type, text);
    await QuickEntryService.notify(result.title, result.body);
    return;
  }

  if (uri.host != 'template') return;
  final i = uri.queryParameters['i'];
  final note = await HomeWidget.getWidgetData<String>('tpl_$i');
  if (note == null || note.trim().isEmpty) return;
  final result = await QuickEntrySaver.save(EntryType.expense, note);
  await QuickEntryService.notify(result.title, result.body);
}
