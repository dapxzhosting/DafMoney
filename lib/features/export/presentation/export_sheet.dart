import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/providers/session_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../categories/presentation/providers/category_providers.dart';
import '../../transactions/presentation/providers/transaction_providers.dart';
import '../../wallets/presentation/providers/wallet_providers.dart';
import '../data/export_service.dart';
import '../data/pdf_exporter.dart';
import '../domain/export_builder.dart';
import '../domain/export_report.dart';
import 'report_image_page.dart';
import '../../../core/widgets/motion.dart';

Future<void> showExportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (_) => const ExportSheet(),
  );
}

enum _Format { pdf, image }

class ExportSheet extends ConsumerStatefulWidget {
  const ExportSheet({super.key});

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  ExportScope _scope = ExportScope.month;
  late DateTime _month;
  late int _year;
  DateRange? _custom;
  _Format _format = _Format.pdf;
  bool _includeEntries = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final sel = ref.read(selectedMonthProvider);
    _month = DateTime(sel.year, sel.month);
    _year = sel.year;
  }

  DateRange get _range => ExportRanges.forScope(
    _scope,
    month: _month,
    year: _year,
    custom: _custom,
  );

  bool get _canGoNext {
    final now = DateTime.now();
    return _scope == ExportScope.month
        ? DateTime(
            _month.year,
            _month.month + 1,
          ).isBefore(DateTime(now.year, now.month + 1))
        : _year < now.year;
  }

  void _step(int delta) {
    setState(() {
      _error = null;
      if (_scope == ExportScope.month) {
        _month = DateTime(_month.year, _month.month + delta);
      } else {
        _year += delta;
      }
    });
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _custom == null
          ? null
          : DateTimeRange(
              start: _custom!.start,
              end: _custom!.end.subtract(const Duration(days: 1)),
            ),
    );
    if (picked == null) return;
    setState(() {
      _error = null;
      _custom = DateRange(
        dateOnly(picked.start),
        DateTime(picked.end.year, picked.end.month, picked.end.day + 1),
      );
    });
  }

  Rect? _origin(BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _generate(Rect? origin) async {
    if (_scope == ExportScope.custom && _custom == null) {
      setState(() => _error = 'Pilih rentang tanggal dulu.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final uid = ref.read(uidProvider);
      if (uid == null) throw const AppException('Sesi berakhir. Masuk lagi.');

      final range = _range;
      final txns = await ref
          .read(transactionRepositoryProvider)
          .watchRange(uid, range)
          .first
          .timeout(const Duration(seconds: 25));
      if (!mounted) return;

      if (txns.isEmpty) {
        setState(() => _error = 'Tidak ada transaksi pada periode ini.');
        return;
      }

      final report = buildExportReport(
        scope: _scope,
        range: range,
        txns: txns,
        cats: ref.read(categoryMapProvider),
        wallets: ref.read(walletMapProvider),
      );

      if (_format == _Format.image) {
        final nav = Navigator.of(context);
        nav.pop();
        unawaited(
          nav.push(
            MaterialPageRoute<void>(
              builder: (_) => ReportImagePage(report: report),
            ),
          ),
        );
        return;
      }

      final bytes = await PdfExporter.build(
        report,
        includeEntries: _includeEntries,
      );
      if (!mounted) return;
      await ExportService.shareBytes(
        bytes: bytes,
        fileName: 'DafMoney_Laporan_${report.fileSlug}.pdf',
        mimeType: 'application/pdf',
        text: '${report.title} ${report.periodLabel} - DafMoney',
        origin: origin,
      );
      if (mounted) Navigator.of(context).pop();
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _error =
              'Data terlalu lama dimuat. Periksa koneksi lalu coba lagi.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _periodLabel {
    switch (_scope) {
      case ExportScope.month:
        return Fmt.monthYear(_month);
      case ExportScope.year:
        return 'Tahun $_year';
      case ExportScope.allYears:
        return 'Seluruh riwayat';
      case ExportScope.custom:
        final c = _custom;
        if (c == null) return 'Pilih rentang tanggal';
        final last = DateTime(c.end.year, c.end.month, c.end.day - 1);
        return '${Fmt.dateShort(c.start)} - ${Fmt.dateShort(last)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final stepper = _scope == ExportScope.month || _scope == ExportScope.year;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Gap.page,
          0,
          Gap.page,
          Gap.md + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ekspor & bagikan laporan',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: Gap.md),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ExportScope>(
                showSelectedIcon: false,
                segments: [
                  for (final s in ExportScope.values)
                    ButtonSegment(value: s, label: Text(s.label)),
                ],
                selected: {_scope},
                onSelectionChanged: (s) => setState(() {
                  _scope = s.first;
                  _error = null;
                  // Daftar transaksi panjang: default mati untuk periode besar.
                  _includeEntries =
                      _scope == ExportScope.month ||
                      _scope == ExportScope.custom;
                }),
              ),
            ),
            const SizedBox(height: Gap.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  if (stepper)
                    IconButton(
                      tooltip: 'Sebelumnya',
                      onPressed: () => _step(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    )
                  else
                    const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        _periodLabel,
                        textAlign: TextAlign.center,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (stepper)
                    IconButton(
                      tooltip: 'Berikutnya',
                      onPressed: _canGoNext ? () => _step(1) : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    )
                  else if (_scope == ExportScope.custom)
                    IconButton(
                      tooltip: 'Pilih tanggal',
                      onPressed: _pickCustom,
                      icon: const Icon(Icons.date_range_rounded),
                    )
                  else
                    const SizedBox(width: Gap.sm),
                ],
              ),
            ),
            const SizedBox(height: Gap.xs),
            Text(switch (_scope) {
              ExportScope.month => 'Dirangkum per minggu.',
              ExportScope.year => 'Dirangkum per bulan.',
              ExportScope.allYears => 'Seluruh transaksi, dirangkum per tahun.',
              ExportScope.custom =>
                'Dirangkum per minggu, atau per bulan untuk rentang panjang.',
            }, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Expanded(
                  child: _FormatCard(
                    icon: Icons.picture_as_pdf_rounded,
                    title: 'PDF',
                    subtitle: 'Tabel lengkap, siap cetak',
                    selected: _format == _Format.pdf,
                    onTap: () => setState(() => _format = _Format.pdf),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: _FormatCard(
                    icon: Icons.image_rounded,
                    title: 'Gambar',
                    subtitle: 'Kartu ringkas untuk dibagikan',
                    selected: _format == _Format.image,
                    onTap: () => setState(() => _format = _Format.image),
                  ),
                ),
              ],
            ),
            if (_format == _Format.pdf)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sertakan daftar transaksi'),
                subtitle: const Text('Matikan untuk PDF yang lebih ringkas'),
                value: _includeEntries,
                onChanged: (v) => setState(() => _includeEntries = v),
              ),
            if (_error != null) ...[
              const SizedBox(height: Gap.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline_rounded, size: 18, color: cs.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: tt.bodySmall?.copyWith(color: cs.error),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: Gap.md),
            Builder(
              builder: (btnContext) => FilledButton.icon(
                onPressed: _busy ? null : () => _generate(_origin(btnContext)),
                icon: _busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        ),
                      )
                    : Icon(
                        _format == _Format.pdf
                            ? Icons.ios_share_rounded
                            : Icons.visibility_rounded,
                      ),
                label: SwapText(
                  _busy
                      ? 'Menyiapkan...'
                      : (_format == _Format.pdf
                            ? 'Buat PDF & bagikan'
                            : 'Buat gambar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(Gap.sm + 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected ? cs.primaryContainer : Colors.transparent,
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
