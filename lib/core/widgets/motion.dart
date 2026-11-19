import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Kurva & durasi standar supaya semua animasi terasa seragam.
class Motion {
  Motion._();

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 520);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve spring = Curves.easeOutBack;
}

/// Efek tekan halus: mengecil sedikit saat disentuh lalu kembali memantul.
/// Bungkus kartu / tombol apa pun tanpa mengubah isi di dalamnya.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: _down ? Motion.fast : Motion.normal,
        curve: _down ? Curves.easeOut : Motion.spring,
        child: AnimatedOpacity(
          opacity: _down ? 0.9 : 1,
          duration: Motion.fast,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Muncul bertahap (fade + naik) dengan jeda berdasarkan [index].
/// Cocok untuk item list / kartu yang tampil berurutan.
class StaggerIn extends StatefulWidget {
  const StaggerIn({
    super.key,
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 60),
    this.offset = 18,
    this.maxIndex = 10,
  });

  final Widget child;
  final int index;
  final Duration step;
  final double offset;
  final int maxIndex;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Motion.enter,
  );

  @override
  void initState() {
    super.initState();
    final i = widget.index.clamp(0, widget.maxIndex);
    Future.delayed(widget.step * i, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (_, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _t.value) * widget.offset),
          child: child,
        ),
      ),
    );
  }
}

/// Transisi halaman untuk go_router: fade + geser tipis + skala sangat kecil.
/// Dipakai lewat `pageBuilder: (c, s) => smoothPage(s, const Page())`.
CustomTransitionPage<T> smoothPage<T>(GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Motion.enter,
        reverseCurve: Motion.exit,
      );
      final out = CurvedAnimation(parent: secondary, curve: Curves.easeInOut);
      return FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: FadeTransition(
              opacity: Tween<double>(begin: 1, end: 0.6).animate(out),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

/// Efek tekan murni visual (tanpa menangkap gesture), aman dibungkus di
/// sekitar widget yang sudah punya InkWell / tombol sendiri.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: _down ? Motion.fast : Motion.normal,
        curve: _down ? Curves.easeOut : Motion.spring,
        child: widget.child,
      ),
    );
  }
}

/// Teks yang berganti dengan animasi: teks lama naik & memudar, teks baru
/// naik dari bawah. Lebar ikut menyesuaikan dengan mulus (cocok untuk
/// label tombol seperti "Transaksi" <-> "Tutup").
class SwapText extends StatelessWidget {
  const SwapText(
    this.text, {
    super.key,
    this.style,
    this.duration = const Duration(milliseconds: 280),
  });

  final String text;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: duration,
      curve: Motion.enter,
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.center,
          children: [...previous, if (current != null) current],
        ),
        transitionBuilder: (child, animation) {
          final incoming = child.key == ValueKey(text);
          final slide = Tween<Offset>(
            begin: incoming ? const Offset(0, 0.6) : const Offset(0, -0.6),
            end: Offset.zero,
          ).animate(animation);
          return ClipRect(
            child: FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            ),
          );
        },
        child: Text(text, key: ValueKey(text), style: style),
      ),
    );
  }
}
