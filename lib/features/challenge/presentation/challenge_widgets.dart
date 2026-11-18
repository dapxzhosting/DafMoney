import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Api tantangan yang bergoyang. [lit] = false menampilkan api padam.
class FlameIcon extends StatelessWidget {
  const FlameIcon({super.key, required this.size, required this.lit});

  final double size;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final icon = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: lit
            ? const [Color(0xFFFF3D00), Color(0xFFFF9100), Color(0xFFFFEA00)]
            : const [Color(0xFF64748B), Color(0xFF94A3B8)],
      ).createShader(rect),
      child: Icon(
        Icons.local_fire_department_rounded,
        size: size,
        color: Colors.white,
      ),
    );

    if (!lit) return icon;

    return SizedBox(
      width: size * 1.8,
      height: size * 1.8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
                width: size * 1.6,
                height: size * 1.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFF9100).withValues(alpha: 0.45),
                      const Color(0xFFFF9100).withValues(alpha: 0),
                    ],
                  ),
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1.15, 1.15),
                duration: 1300.ms,
                curve: Curves.easeInOut,
              ),
          icon
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.08, 1.1),
                duration: 700.ms,
                curve: Curves.easeInOut,
              )
              .moveY(begin: 1.5, end: -1.5, duration: 700.ms),
        ],
      ),
    );
  }
}

/// Cincin kemajuan menuju target.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.size,
    required this.child,
    this.color = Colors.white,
    this.track,
    this.stroke = 12,
  });

  final double progress;
  final double size;
  final Widget child;
  final Color color;
  final Color? track;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: v,
            color: color,
            track: track ?? color.withValues(alpha: 0.2),
            stroke: stroke,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Hujan konfeti sekali jalan (untuk perayaan).
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _Particle {
  _Particle(math.Random r)
    : x = r.nextDouble(),
      vx = (r.nextDouble() - 0.5) * 0.35,
      vy = 0.25 + r.nextDouble() * 0.5,
      size = 5 + r.nextDouble() * 6,
      spin = (r.nextDouble() - 0.5) * 12,
      delay = r.nextDouble() * 0.25,
      color = _palette[r.nextInt(_palette.length)];

  static const _palette = [
    Color(0xFFFF3D00),
    Color(0xFFFFC400),
    Color(0xFF00C853),
    Color(0xFF2979FF),
    Color(0xFFD500F9),
    Color(0xFFFF4081),
  ];

  final double x;
  final double vx;
  final double vy;
  final double size;
  final double spin;
  final double delay;
  final Color color;
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward();

  late final List<_Particle> _particles = () {
    final r = math.Random(11);
    return List.generate(70, (_) => _Particle(r));
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          painter: _ConfettiPainter(_particles, _c.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.t);

  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final lt = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0).toDouble();
      if (lt <= 0) continue;
      final x = (p.x + p.vx * lt) * size.width;
      // Naik sebentar lalu jatuh (gravitasi sederhana).
      final y = size.height * (-0.1 + p.vy * lt + 1.1 * lt * lt * 0.6);
      final opacity = lt > 0.8 ? (1 - lt) / 0.2 : 1.0;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * lt);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.6,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
