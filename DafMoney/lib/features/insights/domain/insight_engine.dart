import 'package:flutter/material.dart' show IconData, Icons;

import '../../../core/models/entry_type.dart';
import '../../../core/utils/formatters.dart';
import '../../budgets/domain/budget.dart';
import '../../categories/domain/category.dart';
import '../../categories/presentation/category_style.dart';
import '../../reports/domain/report_calculator.dart';
import '../../transactions/domain/money_transaction.dart';

enum InsightTone { good, warn, info }

class Insight {
  const Insight({
    required this.icon,
    required this.title,
    required this.message,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String message;
  final InsightTone tone;
}

/// Menyusun wawasan otomatis untuk [month] dari transaksi 6 bulan terakhir.
///
/// Perbandingan dengan bulan lalu dibuat adil: bila bulan berjalan belum
/// selesai, bulan lalu hanya dihitung sampai tanggal yang sama.
List<Insight> buildInsights({
  required List<MoneyTransaction> all,
  required DateTime month,
  required Map<String, Category> cats,
  required List<BudgetProgress> budgets,
}) {
  final now = DateTime.now();
  final isCurrent = month.year == now.year && month.month == now.month;
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final cutoff = isCurrent ? now.day : daysInMonth;
  final prevMonth = DateTime(month.year, month.month - 1);

  final cur = all
      .where((t) => t.date.year == month.year && t.date.month == month.month)
      .toList();
  if (cur.isEmpty) return const [];

  final prev = all
      .where(
        (t) =>
            t.date.year == prevMonth.year &&
            t.date.month == prevMonth.month &&
            t.date.day <= cutoff,
      )
      .toList();

  final curSum = summarize(cur);
  final prevSum = summarize(prev);
  final out = <Insight>[];

  // 1. Anggaran yang paling mepet / terlewati.
  BudgetProgress? worst;
  for (final b in budgets) {
    if (b.ratio >= 0.8 && (worst == null || b.ratio > worst.ratio)) worst = b;
  }
  if (worst != null) {
    final name = resolveCategory(cats, worst.budget.categoryId).name;
    final pct = (worst.ratio * 100).round();
    out.add(
      worst.ratio >= 1
          ? Insight(
              icon: Icons.warning_amber_rounded,
              title: 'Anggaran $name terlewati',
              message:
                  'Terpakai $pct%, lebih ${Fmt.rupiah(-worst.remaining)} dari batas.',
              tone: InsightTone.warn,
            )
          : Insight(
              icon: Icons.speed_rounded,
              title: 'Anggaran $name hampir habis',
              message: 'Terpakai $pct%. Sisa ${Fmt.rupiah(worst.remaining)}.',
              tone: InsightTone.warn,
            ),
    );
  }

  // 2. Total pengeluaran vs bulan lalu.
  if (prevSum.expense > 0 && curSum.expense > 0) {
    final change = (curSum.expense - prevSum.expense) / prevSum.expense;
    final diff = (curSum.expense - prevSum.expense).abs();
    final pct = (change.abs() * 100).round();
    if (change >= 0.10) {
      out.add(
        Insight(
          icon: Icons.trending_up_rounded,
          title: 'Pengeluaran naik $pct%',
          message:
              'Lebih besar ${Fmt.rupiah(diff)} dari periode yang sama bulan lalu.',
          tone: InsightTone.warn,
        ),
      );
    } else if (change <= -0.10) {
      out.add(
        Insight(
          icon: Icons.trending_down_rounded,
          title: 'Pengeluaran turun $pct%',
          message:
              'Hemat ${Fmt.rupiah(diff)} dibanding periode yang sama bulan lalu.',
          tone: InsightTone.good,
        ),
      );
    }
  }

  // 3. Kategori yang paling melonjak.
  final prevByCat = {
    for (final c in byCategory(prev, EntryType.expense)) c.categoryId: c.total,
  };
  CategoryTotal? growth;
  var growthDiff = 0;
  for (final c in byCategory(cur, EntryType.expense)) {
    final p = prevByCat[c.categoryId] ?? 0;
    final d = c.total - p;
    if (p > 0 && c.total / p >= 1.3 && d >= 50000 && d > growthDiff) {
      growth = c;
      growthDiff = d;
    }
  }
  if (growth != null) {
    final p = prevByCat[growth.categoryId]!;
    final pct = ((growth.total - p) / p * 100).round();
    final look = resolveCategory(cats, growth.categoryId);
    out.add(
      Insight(
        icon: look.icon,
        title: '${look.name} naik $pct%',
        message: 'Bertambah ${Fmt.rupiah(growthDiff)} dibanding bulan lalu.',
        tone: InsightTone.warn,
      ),
    );
  }

  // 4. Tingkat tabungan.
  if (curSum.income > 0) {
    final rate = curSum.net / curSum.income;
    final pct = (rate * 100).round();
    if (rate >= 0.2) {
      out.add(
        Insight(
          icon: Icons.savings_rounded,
          title: 'Kamu menabung $pct%',
          message: 'Dari pemasukan bulan ini. Pertahankan ritmenya!',
          tone: InsightTone.good,
        ),
      );
    } else if (rate < 0) {
      out.add(
        Insight(
          icon: Icons.money_off_rounded,
          title: 'Pengeluaran melebihi pemasukan',
          message: 'Defisit ${Fmt.rupiah(-curSum.net)} bulan ini.',
          tone: InsightTone.warn,
        ),
      );
    } else {
      out.add(
        Insight(
          icon: Icons.savings_rounded,
          title: 'Tingkat tabungan $pct%',
          message: 'Sisihkan sedikit lagi untuk mencapai 20%.',
          tone: InsightTone.info,
        ),
      );
    }
  }

  // 5. Kategori pengeluaran terbesar.
  final cats0 = byCategory(cur, EntryType.expense);
  if (cats0.isNotEmpty && curSum.expense > 0) {
    final top = cats0.first;
    final look = resolveCategory(cats, top.categoryId);
    final pct = (top.total / curSum.expense * 100).round();
    out.add(
      Insight(
        icon: look.icon,
        title: '${look.name} terbesar',
        message: '$pct% dari pengeluaran bulan ini (${Fmt.rupiah(top.total)}).',
        tone: InsightTone.info,
      ),
    );
  }

  // 6. Hari tanpa pengeluaran.
  final spendDays = <int>{
    for (final t in cur)
      if (t.type == EntryType.expense) t.date.day,
  };
  var noSpend = 0;
  for (var d = 1; d <= cutoff; d++) {
    if (!spendDays.contains(d)) noSpend++;
  }
  if (noSpend >= 3 && curSum.expense > 0) {
    out.add(
      Insight(
        icon: Icons.event_available_rounded,
        title: '$noSpend hari tanpa pengeluaran',
        message: 'Dari $cutoff hari yang sudah berjalan. Mantap!',
        tone: InsightTone.good,
      ),
    );
  }

  // 7. Pengeluaran tunggal terbesar.
  MoneyTransaction? biggest;
  for (final t in cur) {
    if (t.type == EntryType.expense &&
        (biggest == null || t.amount > biggest.amount)) {
      biggest = t;
    }
  }
  if (biggest != null) {
    final look = resolveCategory(cats, biggest.categoryId);
    out.add(
      Insight(
        icon: Icons.bolt_rounded,
        title: 'Terbesar: ${Fmt.rupiah(biggest.amount)}',
        message: '${look.name}, ${Fmt.dateShort(biggest.date)}.',
        tone: InsightTone.info,
      ),
    );
  }

  return out.take(6).toList();
}
