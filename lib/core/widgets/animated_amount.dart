import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/privacy_providers.dart';
import '../utils/formatters.dart';

/// Menampilkan nominal rupiah dengan animasi hitung naik/turun, dan
/// menggantinya dengan titik-titik saat saldo disembunyikan.
class AnimatedAmount extends ConsumerWidget {
  const AnimatedAmount({
    super.key,
    required this.value,
    this.style,
    this.maskable = true,
    this.duration = const Duration(milliseconds: 800),
  });

  final int value;
  final TextStyle? style;

  /// false = selalu tampil, tidak ikut pengaturan sembunyikan saldo.
  final bool maskable;
  final Duration duration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = maskable && ref.watch(hideBalanceProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: hidden
          ? Text('Rp ••••••', key: const ValueKey('hidden'), style: style)
          : TweenAnimationBuilder<double>(
              key: const ValueKey('shown'),
              tween: Tween<double>(begin: 0, end: value.toDouble()),
              duration: duration,
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Text(Fmt.rupiah(v.round()), style: style),
            ),
    );
  }
}
