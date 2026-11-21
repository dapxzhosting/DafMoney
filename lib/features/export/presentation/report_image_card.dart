import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/formatters.dart';
import '../domain/export_report.dart';

class ReportImageCard extends StatelessWidget {
  const ReportImageCard({super.key, required this.report});

  final ExportReport report;

  static const double width = 360;

  static const _bg = Color(0xFFF3F7F5);
  static const _brand = Color(0xFF0E9F6E);
  static const _brandDark = Color(0xFF07583F);
  static const _income = Color(0xFF16A34A);
  static const _expense = Color(0xFFE5484D);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _line = Color(0xFFE3EBE8);

  static TextStyle _t(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = _ink,
    double? spacing,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: spacing,
    decoration: TextDecoration.none,
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: _bg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(report: report),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ChartCard(report: report),
                  const SizedBox(height: 12),
                  _CategoryCard(report: report),
                  const SizedBox(height: 12),
                  _StatsRow(report: report),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Dibuat dengan DafMoney  •  ${Fmt.dateShort(report.generatedAt)}',
                      style: _t(10, color: _muted, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.report});

  final ExportReport report;

  @override
  Widget build(BuildContext context) {
    final t = ReportImageCard._t;
    final net = report.net;
    final netText = '${net > 0 ? '+' : ''}${Fmt.rupiah(net)}';

    Widget pill(IconData icon, String label, int value) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: t(
                      10,
                      color: Colors.white.withValues(alpha: 0.85),
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      Fmt.rupiah(value),
                      style: t(
                        13,
                        color: Colors.white,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [ReportImageCard._brand, ReportImageCard._brandDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -70, right: -50, child: _glow(220, 0.16)),
            Positioned(bottom: -90, left: -60, child: _glow(200, 0.10)),
            Positioned(
              top: 54,
              right: 40,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'DafMoney',
                        style: t(
                          14,
                          color: Colors.white,
                          weight: FontWeight.w800,
                          spacing: -0.2,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          report.title.replaceFirst('Laporan ', ''),
                          style: t(
                            10,
                            color: Colors.white,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Laporan Keuangan',
                    style: t(
                      12,
                      color: Colors.white.withValues(alpha: 0.8),
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    report.periodLabel,
                    style: t(
                      24,
                      color: Colors.white,
                      weight: FontWeight.w800,
                      spacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Selisih',
                    style: t(
                      11,
                      color: Colors.white.withValues(alpha: 0.8),
                      weight: FontWeight.w600,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      netText,
                      style: t(
                        32,
                        color: Colors.white,
                        weight: FontWeight.w800,
                        spacing: -1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      pill(
                        Icons.arrow_downward_rounded,
                        'Pemasukan',
                        report.income,
                      ),
                      const SizedBox(width: 8),
                      pill(
                        Icons.arrow_upward_rounded,
                        'Pengeluaran',
                        report.expense,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glow(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          Colors.white.withValues(alpha: alpha),
          Colors.white.withValues(alpha: 0),
        ],
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ReportImageCard._line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: ReportImageCard._t(13, weight: FontWeight.w800)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.report});

  final ExportReport report;

  @override
  Widget build(BuildContext context) {
    final t = ReportImageCard._t;
    final maxV = report.buckets.fold<int>(0, (m, b) {
      final v = b.income > b.expense ? b.income : b.expense;
      return v > m ? v : m;
    });
    const barArea = 110.0;
    double h(int v) => maxV == 0 ? 0 : (v / maxV) * barArea;
    final many = report.buckets.length > 8;
    final barW = many ? 5.0 : 9.0;

    Widget bar(double height, Color color) => Container(
      width: barW,
      height: height < 2 && height > 0 ? 2 : height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.vertical(top: Radius.circular(barW / 2)),
      ),
    );

    Widget legend(Color c, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(text, style: t(10, color: ReportImageCard._muted)),
      ],
    );

    return _Panel(
      title: report.bucketTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: barArea + 22,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final b in report.buckets)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            bar(h(b.income), ReportImageCard._income),
                            SizedBox(width: many ? 1.5 : 3),
                            bar(h(b.expense), ReportImageCard._expense),
                          ],
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            b.label,
                            style: t(
                              many ? 8 : 9,
                              color: ReportImageCard._muted,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.only(top: 2, bottom: 10),
            color: ReportImageCard._line,
          ),
          Row(
            children: [
              legend(ReportImageCard._income, 'Pemasukan'),
              const SizedBox(width: 14),
              legend(ReportImageCard._expense, 'Pengeluaran'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.report});

  final ExportReport report;

  @override
  Widget build(BuildContext context) {
    final t = ReportImageCard._t;
    final top = report.expenseCategories.take(5).toList();

    return _Panel(
      title: 'Pengeluaran terbesar',
      child: top.isEmpty
          ? Text(
              'Belum ada pengeluaran.',
              style: t(12, color: ReportImageCard._muted),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < top.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _CategoryRow(category: top[i]),
                ],
              ],
            ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category});

  final ExportCategory category;

  @override
  Widget build(BuildContext context) {
    final t = ReportImageCard._t;
    final fill = (category.ratio * 100).round().clamp(1, 100).toInt();
    final rest = 100 - fill;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: category.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t(12, weight: FontWeight.w700),
              ),
            ),
            Text(
              '${(category.ratio * 100).round()}%',
              style: t(
                11,
                color: ReportImageCard._muted,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              Fmt.rupiah(category.total),
              style: t(12, weight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Row(
              children: [
                Expanded(
                  flex: fill,
                  child: ColoredBox(color: category.color),
                ),
                if (rest > 0)
                  Expanded(
                    flex: rest,
                    child: const ColoredBox(color: Color(0xFFEEF3F1)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.report});

  final ExportReport report;

  @override
  Widget build(BuildContext context) {
    final t = ReportImageCard._t;
    final rate = report.savingsRate;

    Widget stat(IconData icon, String label, String value, Color color) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ReportImageCard._line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: t(14, weight: FontWeight.w800, spacing: -0.3),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t(
                    9.5,
                    color: ReportImageCard._muted,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );

    return Row(
      children: [
        stat(
          Icons.today_rounded,
          'Rata-rata / hari',
          Fmt.rupiahCompact(report.avgDailyExpense),
          ReportImageCard._expense,
        ),
        const SizedBox(width: 8),
        stat(
          Icons.savings_rounded,
          'Tingkat tabungan',
          rate == null ? '-' : '${(rate * 100).round()}%',
          ReportImageCard._brand,
        ),
        const SizedBox(width: 8),
        stat(
          Icons.receipt_long_rounded,
          'Transaksi',
          '${report.transactionCount}',
          const Color(0xFF6366F1),
        ),
      ],
    );
  }
}
