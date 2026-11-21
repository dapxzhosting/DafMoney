import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/session_providers.dart';
import '../../../core/utils/snackbar.dart';
import '../../categories/presentation/providers/category_providers.dart';
import '../../export/data/export_service.dart';
import '../../transactions/presentation/providers/transaction_providers.dart';
import '../../wallets/presentation/providers/wallet_providers.dart';
import '../data/import_service.dart';
import '../domain/csv_transactions.dart';

final importServiceProvider = Provider<ImportService>(
  (ref) => ImportService(ref.watch(firestoreProvider)),
);

class CsvPage extends ConsumerStatefulWidget {
  const CsvPage({super.key});

  @override
  ConsumerState<CsvPage> createState() => _CsvPageState();
}

class _CsvPageState extends ConsumerState<CsvPage> {
  bool _busy = false;
  String? _fileName;
  ImportPreview? _preview;
  ImportPlan? _plan;
  ({int done, int total})? _progress;

  String get _uid =>
      ref.read(uidProvider) ??
      (throw const AppException('Sesi berakhir. Masuk lagi.'));

  Future<String> _buildCsv() async {
    final txns = await ref.read(transactionRepositoryProvider).fetchAll(_uid);
    if (txns.isEmpty) {
      throw const AppException('Belum ada transaksi untuk diekspor.');
    }
    final cats = (await ref.read(categoriesProvider.future));
    final wallets = (await ref.read(walletsProvider.future));
    return buildTransactionsCsv(
      txns,
      {for (final c in cats) c.id: c},
      {for (final w in wallets) w.id: w},
    );
  }

  Future<void> _guard(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) context.showSnack(errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() => _guard(() async {
    final csv = await _buildCsv();
    final d = DateTime.now();
    final stamp =
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    // BOM agar Excel membaca UTF-8 (huruf non-ASCII) dengan benar.
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
    await ExportService.shareBytes(
      bytes: bytes,
      fileName: 'DafMoney_transaksi_$stamp.csv',
      mimeType: 'text/csv',
      text: 'Transaksi DafMoney',
    );
  });

  Future<void> _copy() => _guard(() async {
    final csv = await _buildCsv();
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) context.showSnack('CSV disalin ke papan klip.');
  });

  Future<void> _pick() => _guard(() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.single;
    Uint8List? bytes = f.bytes;
    if (bytes == null && f.path != null) {
      bytes = await File(f.path!).readAsBytes();
    }
    if (bytes == null) throw const AppException('Berkas tidak bisa dibaca.');
    if (bytes.length > 10 * 1024 * 1024) {
      throw const AppException('Berkas terlalu besar (maksimal 10 MB).');
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    final preview = parseTransactionsCsv(text);
    final existing = await ref
        .read(transactionRepositoryProvider)
        .fetchAll(_uid);
    final cats = await ref.read(categoriesProvider.future);
    final wallets = await ref.read(walletsProvider.future);
    final plan = planImport(
      rows: preview.rows,
      existing: existing,
      categories: {for (final c in cats) c.id: c},
      wallets: wallets,
    );
    if (!mounted) return;
    setState(() {
      _fileName = f.name;
      _preview = preview;
      _plan = plan;
      _progress = null;
    });
  });

  Future<void> _import() async {
    final plan = _plan;
    if (plan == null || plan.toImport.isEmpty) return;
    setState(() {
      _busy = true;
      _progress = (done: 0, total: plan.toImport.length);
    });
    try {
      final cats = await ref.read(categoriesProvider.future);
      final wallets = await ref.read(walletsProvider.future);
      final n = await ref
          .read(importServiceProvider)
          .run(
            _uid,
            plan: plan,
            categories: {for (final c in cats) c.id: c},
            wallets: wallets,
            onProgress: (done, total) {
              if (mounted) setState(() => _progress = (done: done, total: total));
            },
          );
      ref.read(dataVersionProvider.notifier).bump();
      if (!mounted) return;
      setState(() {
        _preview = null;
        _plan = null;
        _fileName = null;
        _progress = null;
      });
      context.showSnack('$n transaksi berhasil diimpor.');
    } catch (e) {
      if (mounted) {
        setState(() => _progress = null);
        context.showSnack(
          e is StateError ? e.message : errorText(e),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final preview = _preview;
    final plan = _plan;

    return Scaffold(
      appBar: AppBar(title: const Text('Impor & ekspor CSV')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.upload_file_rounded, color: cs.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Ekspor transaksi',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Semua transaksi dalam satu berkas CSV (tanggal, jenis, kategori, dompet, jumlah, catatan). Bisa dibuka di Excel / Google Sheets atau diimpor kembali.',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _share,
                          icon: const Icon(Icons.ios_share_rounded),
                          label: const Text('Bagikan berkas'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _busy ? null : _copy,
                        child: const Text('Salin'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.download_rounded, color: cs.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Impor transaksi',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pilih berkas CSV. Baris pertama harus berisi judul kolom: Tanggal, Jenis (Pemasukan/Pengeluaran), Kategori, Dompet (opsional), Jumlah, Catatan. Kategori atau dompet yang belum ada dibuat otomatis, dan transaksi yang sudah ada dilewati.',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _busy ? null : _pick,
                      icon: const Icon(Icons.folder_open_rounded),
                      label: Text(
                        _fileName == null ? 'Pilih berkas CSV' : 'Ganti berkas',
                      ),
                    ),
                  ),
                  if (_busy && _progress == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
          if (preview != null && plan != null) ...[
            const SizedBox(height: 16),
            _PreviewCard(
              fileName: _fileName ?? '',
              preview: preview,
              plan: plan,
              progress: _progress,
              busy: _busy,
              onImport: _import,
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.fileName,
    required this.preview,
    required this.plan,
    required this.progress,
    required this.busy,
    required this.onImport,
  });

  final String fileName;
  final ImportPreview preview;
  final ImportPlan plan;
  final ({int done, int total})? progress;
  final bool busy;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final n = plan.toImport.length;

    Widget line(IconData icon, String text, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );

    return Card(
      color: cs.primaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pratinjau · $fileName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            line(
              Icons.check_circle_rounded,
              '$n transaksi siap diimpor',
              color: Colors.green,
            ),
            if (plan.duplicates > 0)
              line(
                Icons.content_copy_rounded,
                '${plan.duplicates} sudah ada, dilewati',
              ),
            if (plan.newCategories.isNotEmpty)
              line(
                Icons.category_rounded,
                '${plan.newCategories.length} kategori baru akan dibuat',
              ),
            if (plan.newWallets.isNotEmpty)
              line(
                Icons.account_balance_wallet_rounded,
                '${plan.newWallets.length} dompet baru akan dibuat',
              ),
            if (preview.errors.isNotEmpty)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    '${preview.errors.length} baris bermasalah (dilewati)',
                    style: TextStyle(color: cs.error),
                  ),
                  leading: Icon(Icons.warning_amber_rounded, color: cs.error),
                  children: [
                    for (final e in preview.errors.take(50))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(e, style: tt.bodySmall),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (progress != null) ...[
              LinearProgressIndicator(
                value: progress!.total == 0
                    ? null
                    : progress!.done / progress!.total,
              ),
              const SizedBox(height: 6),
              Text('${progress!.done} / ${progress!.total}'),
            ] else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (busy || n == 0) ? null : onImport,
                  child: Text(n == 0 ? 'Tidak ada yang diimpor' : 'Impor $n transaksi'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
