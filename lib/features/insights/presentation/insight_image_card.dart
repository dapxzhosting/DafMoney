import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/formatters.dart';
import '../domain/insight_engine.dart';

/// Kartu wawasan berukuran tetap yang di-render ke gambar PNG untuk dibagikan.
class InsightImageCard extends StatelessWidget {
  const InsightImageCard({
    super.key,
    required this.insight,
    required this.periodLabel,
    required this.generatedAt,
  });

  final Insight insight;
  final String periodLabel;
  final DateTime generatedAt;

  static const double width = 360;
  static const double height = 450;

  static List<Color> colorsFor(InsightTone t) {
    switch (t) {
      case InsightTone.good:
        return const [Color(0xFF10B981), Color(0xFF047857)];
      case InsightTone.warn:
        return const [Color(0xFFF59E0B), Color(0xFFDC2626)];
      case InsightTone.info:
        return const [Color(0xFF3B82F6), Color(0xFF6366F1)];
    }
  }

  static TextStyle _t(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = Colors.white,
    double? height,
    double? spacing,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: spacing,
    decoration: TextDecoration.none,
  );

  @override
  Widget build(BuildContext context) {
    final colors = colorsFor(insight.tone);
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -70,
              top: -70,
              child: _Blob(size: 240, alpha: 0.10),
            ),
            Positioned(
              left: -60,
              bottom: 40,
              child: _Blob(size: 180, alpha: 0.07),
            ),
            Positioned(
              right: 40,
              bottom: -70,
              child: _Blob(size: 160, alpha: 0.08),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'WAWASAN',
                          style: _t(11, weight: FontWeight.w800, spacing: 1.4),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        periodLabel,
                        style: _t(
                          12,
                          weight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                    child: Icon(insight.icon, color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    insight.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: _t(28, weight: FontWeight.w800, height: 1.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    insight.message,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: _t(
                      15,
                      height: 1.45,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const Spacer(flex: 2),
                  Container(height: 1, color: Colors.white.withValues(alpha: 0.25)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'DafMoney',
                        style: _t(13, weight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Text(
                        Fmt.dateShort(generatedAt),
                        style: _t(
                          11,
                          weight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
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
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );
}
