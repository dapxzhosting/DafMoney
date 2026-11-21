import 'package:flutter/material.dart';

/// Ilustrasi dalam kartu putih membulat.
///
/// Gambar sumbernya berlatar putih, jadi dibingkai dalam kartu putih supaya
/// tampil rapi baik di tema terang maupun gelap (tanpa kotak putih yang
/// "menempel" di latar gelap). [tilted] menambahkan blok warna miring di
/// belakang kartu sebagai aksen.
class Illustration extends StatelessWidget {
  const Illustration(
    this.asset, {
    super.key,
    this.size = 160,
    this.tilted = false,
  });

  final String asset;
  final double size;
  final bool tilted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(size * 0.18);
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final card = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.05),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: dark
            ? null
            : Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.14),
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          cacheWidth: (size * dpr).round(),
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        ),
      ),
    );

    if (!tilted) return card;

    return SizedBox(
      width: size + 24,
      height: size + 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -0.12,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: dark ? 0.5 : 0.85),
                borderRadius: radius,
              ),
            ),
          ),
          card,
        ],
      ),
    );
  }
}
