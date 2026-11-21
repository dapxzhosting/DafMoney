import 'dart:ui' show DartPluginRegistrant;

import 'package:home_widget/home_widget.dart';

import '../models/entry_type.dart';
import 'quick_entry_saver.dart';
import 'quick_entry_service.dart';

class QuickTemplates {
  QuickTemplates._();

  static const _widgetName = 'DafMoneyWidgetProvider';
  static const slots = 6;

  static Future<void> init() async {
    await HomeWidget.registerInteractivityCallback(
      quickWidgetBackgroundCallback,
    );
  }

  static Future<void> refresh() async {
    try {
      final top = await QuickEntrySaver.topNotes(
        EntryType.expense,
        limit: slots,
      );
      for (var i = 1; i <= slots; i++) {
        final n = i <= top.length ? top[i - 1] : null;
        await HomeWidget.saveWidgetData<String>('tpl_$i', n?.note ?? '');
        await HomeWidget.saveWidgetData<String>(
          'tpl_${i}_label',
          n?.label ?? '',
        );
      }
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: _widgetName,
      );
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      for (var i = 1; i <= slots; i++) {
        await HomeWidget.saveWidgetData<String>('tpl_$i', '');
        await HomeWidget.saveWidgetData<String>('tpl_${i}_label', '');
      }
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: _widgetName,
      );
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
Future<void> quickWidgetBackgroundCallback(Uri? uri) async {
  DartPluginRegistrant.ensureInitialized();
  if (uri == null) return;

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
