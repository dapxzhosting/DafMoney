import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Kotak abu-abu dengan kilau yang bergerak, pengganti spinner saat memuat.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 10,
    this.color,
  });

  final double? width;
  final double height;
  final double radius;

  /// Warna dasar. Kosong = otomatis mengikuti tema.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = color ?? cs.onSurface.withValues(alpha: dark ? 0.10 : 0.07);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(radius),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1300.ms,
          color: Colors.white.withValues(alpha: dark ? 0.10 : 0.55),
        );
  }
}

/// Daftar kerangka bentuk kartu transaksi.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 5,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 0),
  });

  final int count;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: _SkeletonTile(),
            ),
        ],
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SkeletonBox(width: 44, height: 44, radius: 15),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 110, height: 14),
                  SizedBox(height: 8),
                  SkeletonBox(width: 170, height: 11),
                ],
              ),
            ),
            SizedBox(width: 8),
            SkeletonBox(width: 64, height: 14),
          ],
        ),
      ),
    );
  }
}
