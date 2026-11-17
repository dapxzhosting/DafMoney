import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/painting.dart' show Color;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/models/entry_type.dart';
import '../../../core/utils/formatters.dart';
import '../domain/export_report.dart';

/// Membuat laporan PDF (A4) dari [ExportReport].
abstract class PdfExporter {
  static Future<Uint8List> build(
    ExportReport report, {
    required bool includeEntries,
  }) {
    return _PdfBuilder(report, includeEntries).build();
  }
}

class _PdfBuilder {
  _PdfBuilder(this.r, this.includeEntries);

  final ExportReport r;
  final bool includeEntries;

  final pw.Font _reg = pw.Font.helvetica();
  final pw.Font _boldFont = pw.Font.helveticaBold();

  static final _brand = PdfColor.fromInt(0xFF0E9F6E);
  static final _brandDark = PdfColor.fromInt(0xFF0A6F4D);
  static final _income = PdfColor.fromInt(0xFF16A34A);
  static final _expense = PdfColor.fromInt(0xFFE5484D);
  static final _ink = PdfColor.fromInt(0xFF0F172A);
  static final _muted = PdfColor.fromInt(0xFF64748B);
  static final _line = PdfColor.fromInt(0xFFE2E8F0);
  static final _soft = PdfColor.fromInt(0xFFF1F5F4);
  static final _white = PdfColor.fromInt(0xFFFFFFFF);

  pw.TextStyle _s(double size, {PdfColor? color}) =>
      pw.TextStyle(font: _reg, fontSize: size, color: color ?? _ink);

  pw.TextStyle _b(double size, {PdfColor? color}) =>
      pw.TextStyle(font: _boldFont, fontSize: size, color: color ?? _ink);

  /// Font bawaan PDF hanya mendukung Latin-1: buang karakter lain (mis. emoji).
  static String _t(String s) {
    final b = StringBuffer();
    for (final c in s.runes) {
      if (c == 0xA0) {
        b.write(' ');
      } else if (c == 0x2013 || c == 0x2014) {
        b.write('-');
      } else if (c >= 0x20 && c < 0x100) {
        b.writeCharCode(c);
      }
    }
    return b.toString().trim();
  }

  static String _money(int v) => _t(Fmt.rupiah(v));

  static PdfColor _pdf(Color c) => PdfColor.fromInt(c.toARGB32());

  Future<Uint8List> build() async {
    final doc = pw.Document(
      title: '${r.title} ${r.periodLabel}',
      author: 'DafMoney',
      creator: 'DafMoney',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 36),
        maxPages: 2000,
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('DafMoney', style: _s(8, color: _muted)),
              pw.Text(
                'Halaman ${ctx.pageNumber} / ${ctx.pagesCount}',
                style: _s(8, color: _muted),
              ),
            ],
          ),
        ),
        build: (ctx) => [
          _header(),
          pw.SizedBox(height: 14),
          _summary(),
          pw.SizedBox(height: 18),
          _section(r.bucketTitle),
          _barChart(),
          pw.SizedBox(height: 8),
          _bucketTable(),
          pw.SizedBox(height: 18),
          _section('Pengeluaran per kategori'),
          ..._categoryRows(r.expenseCategories, _expense),
          if (r.incomeCategories.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _section('Pemasukan per kategori'),
            ..._categoryRows(r.incomeCategories, _income),
          ],
          if (includeEntries && r.entries.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _section('Daftar transaksi (${r.entries.length})'),
            _entryTable(),
          ],
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _header() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: _brand,
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('DafMoney', style: _b(10, color: _white)),
                pw.SizedBox(height: 6),
                pw.Text(_t(r.title), style: _b(20, color: _white)),
                pw.SizedBox(height: 2),
                pw.Text(_t(r.periodLabel), style: _s(12, color: _white)),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Dibuat pada', style: _s(8, color: _white)),
              pw.Text(
                _t(Fmt.dateShort(r.generatedAt)),
                style: _b(10, color: _white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _statBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _soft,
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: _line, width: 0.6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: _s(8, color: _muted)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: _b(13, color: color)),
          ],
        ),
      ),
    );
  }

  pw.Widget _summary() {
    final rate = r.savingsRate == null
        ? '-'
        : '${(r.savingsRate! * 100).round()}%';
    return pw.Column(
      children: [
        pw.Row(
          children: [
            _statBox('Pemasukan', _money(r.income), _income),
            pw.SizedBox(width: 8),
            _statBox('Pengeluaran', _money(r.expense), _expense),
            pw.SizedBox(width: 8),
            _statBox(
              'Selisih',
              '${r.net > 0 ? '+' : ''}${_money(r.net)}',
              r.net >= 0 ? _brandDark : _expense,
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            _statBox(
              'Rata-rata pengeluaran / hari',
              _money(r.avgDailyExpense),
              _ink,
            ),
            pw.SizedBox(width: 8),
            _statBox('Tingkat tabungan', rate, _ink),
            pw.SizedBox(width: 8),
            _statBox('Jumlah transaksi', '${r.transactionCount}', _ink),
          ],
        ),
      ],
    );
  }

  pw.Widget _section(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(_t(title), style: _b(12)),
    );
  }

  pw.Widget _barChart() {
    final maxV = r.buckets.fold<int>(
      0,
      (m, b) => math.max(m, math.max(b.income, b.expense)),
    );
    const h = 90.0;
    double hh(int v) => maxV == 0 ? 0 : (v / maxV) * h;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          height: h + 20,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.8)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              for (final b in r.buckets)
                pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Container(
                            width: 7,
                            height: hh(b.income),
                            color: _income,
                          ),
                          pw.SizedBox(width: 2),
                          pw.Container(
                            width: 7,
                            height: hh(b.expense),
                            color: _expense,
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(_t(b.label), style: _s(7, color: _muted)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Container(width: 8, height: 8, color: _income),
            pw.SizedBox(width: 4),
            pw.Text('Pemasukan', style: _s(8, color: _muted)),
            pw.SizedBox(width: 12),
            pw.Container(width: 8, height: 8, color: _expense),
            pw.SizedBox(width: 4),
            pw.Text('Pengeluaran', style: _s(8, color: _muted)),
          ],
        ),
      ],
    );
  }

  pw.Widget _cell(
    String text, {
    pw.TextStyle? style,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(text, style: style ?? _s(9), textAlign: align),
    );
  }

  pw.Widget _bucketTable() {
    pw.TableRow row(String a, int inc, int exp, {bool total = false}) {
      final st = total ? _b(9) : _s(9);
      final net = inc - exp;
      return pw.TableRow(
        decoration: pw.BoxDecoration(color: total ? _soft : null),
        children: [
          _cell(a, style: st),
          _cell(_money(inc), style: st, align: pw.TextAlign.right),
          _cell(_money(exp), style: st, align: pw.TextAlign.right),
          _cell(
            '${net > 0 ? '+' : ''}${_money(net)}',
            style: total
                ? _b(9, color: net >= 0 ? _brandDark : _expense)
                : _s(9, color: net >= 0 ? _ink : _expense),
            align: pw.TextAlign.right,
          ),
        ],
      );
    }

    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(1.4),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _line, width: 0.5),
        bottom: pw.BorderSide(color: _line, width: 0.5),
      ),
      children: [
        pw.TableRow(
          repeat: true,
          decoration: pw.BoxDecoration(color: _soft),
          children: [
            _cell('Periode', style: _b(8, color: _muted)),
            _cell(
              'Pemasukan',
              style: _b(8, color: _muted),
              align: pw.TextAlign.right,
            ),
            _cell(
              'Pengeluaran',
              style: _b(8, color: _muted),
              align: pw.TextAlign.right,
            ),
            _cell(
              'Selisih',
              style: _b(8, color: _muted),
              align: pw.TextAlign.right,
            ),
          ],
        ),
        for (final b in r.buckets) row(_t(b.label), b.income, b.expense),
        row('Total', r.income, r.expense, total: true),
      ],
    );
  }

  List<pw.Widget> _categoryRows(List<ExportCategory> list, PdfColor accent) {
    if (list.isEmpty) {
      return [pw.Text('Tidak ada data.', style: _s(9, color: _muted))];
    }
    return [
      for (final c in list)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3.5),
          child: pw.Row(
            children: [
              pw.Container(
                width: 8,
                height: 8,
                decoration: pw.BoxDecoration(
                  color: _pdf(c.color),
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                flex: 4,
                child: pw.Text(
                  _t(c.name).isEmpty ? 'Tanpa nama' : _t(c.name),
                  style: _s(9),
                  maxLines: 1,
                ),
              ),
              pw.Expanded(flex: 4, child: _ratioBar(c.ratio, _pdf(c.color))),
              pw.SizedBox(width: 8),
              pw.SizedBox(
                width: 34,
                child: pw.Text(
                  '${(c.ratio * 100).round()}%',
                  style: _s(9, color: _muted),
                  textAlign: pw.TextAlign.right,
                ),
              ),
              pw.SizedBox(
                width: 86,
                child: pw.Text(
                  _money(c.total),
                  style: _b(9),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  pw.Widget _ratioBar(double ratio, PdfColor color) {
    final fill = (ratio * 100).round().clamp(1, 100).toInt();
    final rest = 100 - fill;
    return pw.Row(
      children: [
        pw.Expanded(
          flex: fill,
          child: pw.Container(height: 6, color: color),
        ),
        if (rest > 0)
          pw.Expanded(
            flex: rest,
            child: pw.Container(height: 6, color: _soft),
          ),
      ],
    );
  }

  pw.Widget _entryTable() {
    final df = DateFormat('dd/MM/yy');
    String note(String s) {
      final t = _t(s);
      return t.length > 48 ? '${t.substring(0, 47)}...' : t;
    }

    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(1.3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(3),
        3: const pw.FlexColumnWidth(1.6),
        4: const pw.FlexColumnWidth(2.2),
      },
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _line, width: 0.4),
        bottom: pw.BorderSide(color: _line, width: 0.4),
      ),
      children: [
        pw.TableRow(
          repeat: true,
          decoration: pw.BoxDecoration(color: _soft),
          children: [
            _cell('Tanggal', style: _b(8, color: _muted)),
            _cell('Kategori', style: _b(8, color: _muted)),
            _cell('Catatan', style: _b(8, color: _muted)),
            _cell('Dompet', style: _b(8, color: _muted)),
            _cell(
              'Jumlah',
              style: _b(8, color: _muted),
              align: pw.TextAlign.right,
            ),
          ],
        ),
        for (final e in r.entries)
          pw.TableRow(
            children: [
              _cell(df.format(e.date), style: _s(8)),
              _cell(_t(e.categoryName), style: _s(8)),
              _cell(note(e.note), style: _s(8, color: _muted)),
              _cell(_t(e.walletName), style: _s(8, color: _muted)),
              _cell(
                '${e.type == EntryType.income ? '+' : '-'}${_money(e.amount)}',
                style: _b(
                  8,
                  color: e.type == EntryType.income ? _income : _expense,
                ),
                align: pw.TextAlign.right,
              ),
            ],
          ),
      ],
    );
  }
}
