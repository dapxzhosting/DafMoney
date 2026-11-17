import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/snackbar.dart';
import '../data/export_service.dart';
import '../domain/export_report.dart';
import 'report_image_card.dart';

/// Pratinjau kartu laporan + tombol bagikan / simpan sebagai gambar PNG.
class ReportImagePage extends StatefulWidget {
  const ReportImagePage({super.key, required this.report});

  final ExportReport report;

  @override
  State<ReportImagePage> createState() => _ReportImagePageState();
}

class _ReportImagePageState extends State<ReportImagePage> {
  final _boundaryKey = GlobalKey();
  bool _busy = false;

  Future<Uint8List?> _capture() async {
    final ctx = _boundaryKey.currentContext;
    if (ctx == null) return null;
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
    // Beri waktu agar font dan frame terakhir selesai digambar.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _share(Rect? origin) async {
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      if (bytes == null) {
        throw const AppException('Gagal membuat gambar. Coba lagi.');
      }
      await ExportService.shareBytes(
        bytes: bytes,
        fileName: 'DafMoney_${widget.report.fileSlug}.png',
        mimeType: 'image/png',
        text: '${widget.report.title} ${widget.report.periodLabel} - DafMoney',
        origin: origin,
      );
    } catch (e) {
      if (mounted) context.showSnack(errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pratinjau gambar')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Gap.md),
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: ReportImageCard(report: widget.report),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.xs,
                Gap.page,
                Gap.md,
              ),
              child: Builder(
                builder: (btnContext) => FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          final box =
                              btnContext.findRenderObject() as RenderBox?;
                          final origin = box == null
                              ? null
                              : box.localToGlobal(Offset.zero) & box.size;
                          _share(origin);
                        },
                  icon: _busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Icon(Icons.ios_share_rounded),
                  label: Text(
                    _busy ? 'Menyiapkan...' : 'Bagikan / simpan gambar',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
