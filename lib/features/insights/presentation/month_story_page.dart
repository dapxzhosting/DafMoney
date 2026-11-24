import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/models/entry_type.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/motion.dart';
import '../../export/data/export_service.dart';
import '../../export/domain/export_report.dart';
import '../../export/presentation/report_image_page.dart';

class MonthStoryPage extends StatefulWidget {
  const MonthStoryPage({super.key, required this.report});

  final ExportReport report;

  static Route<void> route(ExportReport report) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => MonthStoryPage(report: report),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<MonthStoryPage> createState() => _MonthStoryPageState();
}

class _MonthStoryPageState extends State<MonthStoryPage>
    with SingleTickerProviderStateMixin {
  static const _slideDuration = Duration(seconds: 6);

  static const _palettes = <List<Color>>[
    [Color(0xFF0E9F6E), Color(0xFF064E3B)],
    [Color(0xFF2563EB), Color(0xFF1E1B4B)],
    [Color(0xFF7C3AED), Color(0xFF831843)],
    [Color(0xFFEA580C), Color(0xFF7C2D12)],
    [Color(0xFFDB2777), Color(0xFF4C0519)],
    [Color(0xFF0891B2), Color(0xFF083344)],
  ];

  late final AnimationController _progress;
  late final List<_SlideKind> _slides;
  int _index = 0;
  bool _forward = true;

  ExportReport get r => widget.report;

  @override
  void initState() {
    super.initState();
    _slides = [
      _SlideKind.intro,
      _SlideKind.totals,
      if (r.expenseCategories.isNotEmpty) _SlideKind.categories,
      if (r.expense > 0 && r.buckets.length > 1) _SlideKind.weeks,
      if (r.entries.any((e) => e.type == EntryType.expense)) _SlideKind.biggest,
      _SlideKind.outro,
    ];
    _progress = AnimationController(vsync: this, duration: _slideDuration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _next(auto: true);
      })
      ..forward();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _next({bool auto = false}) {
    if (_index >= _slides.length - 1) {
      if (!auto) HapticFeedback.selectionClick();
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _forward = true;
      _index++;
    });
    _progress.forward(from: 0);
  }

  void _prev() {
    HapticFeedback.selectionClick();
    if (_index == 0) {
      _progress.forward(from: 0);
      return;
    }
    setState(() {
      _forward = false;
      _index--;
    });
    _progress.forward(from: 0);
  }

  void _openShare() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => ReportImagePage(report: r)));
  }

  Future<void> _shareSlide() async {
    _progress.stop();
    final kind = _slides[_index];
    final colors = _palettes[_index % _palettes.length];
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _StorySharePage(report: r, kind: kind, colors: colors),
      ),
    );
    if (mounted && _index < _slides.length - 1) _progress.forward();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final palette = _palettes[_index % _palettes.length];
    final isLast = _index == _slides.length - 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            if (isLast) {
              if (d.localPosition.dx < size.width * 0.3) _prev();
              return;
            }
            d.localPosition.dx < size.width * 0.3 ? _prev() : _next();
          },
          onLongPressStart: (_) => _progress.stop(),
          onLongPressEnd: (_) {
            if (_index < _slides.length - 1) _progress.forward();
          },
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) > 400) Navigator.of(context).pop();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: palette,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                const _FloatingBubbles(),
                SafeArea(
                  child: Column(
                    children: [
                      _TopBar(
                        controller: _progress,
                        count: _slides.length,
                        index: _index,
                        onClose: () => Navigator.of(context).pop(),
                        onShare: _shareSlide,
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 420),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, anim) {
                            final entering = child.key == ValueKey(_index);
                            final dx =
                                (_forward ? 0.08 : -0.08) * (entering ? 1 : -1);
                            return FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: Offset(dx, 0),
                                  end: Offset.zero,
                                ).animate(anim),
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey(_index),
                            child: _buildSlide(_slides[_index]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(_SlideKind kind) => _slideFor(
    kind,
    r,
    onShare: _openShare,
    onDone: () => Navigator.of(context).pop(),
  );
}

enum _SlideKind { intro, totals, categories, weeks, biggest, outro }

Widget _slideFor(
  _SlideKind kind,
  ExportReport r, {
  bool forImage = false,
  VoidCallback? onShare,
  VoidCallback? onDone,
}) {
  switch (kind) {
    case _SlideKind.intro:
      return _IntroSlide(report: r, forImage: forImage);
    case _SlideKind.totals:
      return _TotalsSlide(report: r);
    case _SlideKind.categories:
      return _CategoriesSlide(report: r);
    case _SlideKind.weeks:
      return _WeeksSlide(report: r);
    case _SlideKind.biggest:
      return _BiggestSlide(report: r);
    case _SlideKind.outro:
      return _OutroSlide(
        report: r,
        forImage: forImage,
        onShare: onShare,
        onDone: onDone,
      );
  }
}

class _StorySharePage extends StatefulWidget {
  const _StorySharePage({
    required this.report,
    required this.kind,
    required this.colors,
  });

  final ExportReport report;
  final _SlideKind kind;
  final List<Color> colors;

  @override
  State<_StorySharePage> createState() => _StorySharePageState();
}

class _StorySharePageState extends State<_StorySharePage> {
  final _boundaryKey = GlobalKey();
  Timer? _settle;
  bool _ready = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _settle = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  Future<Uint8List?> _capture() async {
    final ctx = _boundaryKey.currentContext;
    if (ctx == null) return null;
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
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
        fileName:
            'DafMoney_kilas_${widget.kind.name}_${widget.report.fileSlug}.png',
        mimeType: 'image/png',
        text: 'Kilas ${widget.report.periodLabel} - DafMoney',
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
    final loading = _busy || !_ready;
    return Scaffold(
      appBar: AppBar(title: const Text('Bagikan kilas')),
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
                        child: _StoryImage(
                          report: widget.report,
                          kind: widget.kind,
                          colors: widget.colors,
                        ),
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
                  onPressed: loading
                      ? null
                      : () {
                          final box =
                              btnContext.findRenderObject() as RenderBox?;
                          final origin = box == null
                              ? null
                              : box.localToGlobal(Offset.zero) & box.size;
                          _share(origin);
                        },
                  icon: loading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Icon(Icons.ios_share_rounded),
                  label: SwapText(
                    loading ? 'Menyiapkan...' : 'Bagikan / simpan gambar',
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

class _StoryImage extends StatelessWidget {
  const _StoryImage({
    required this.report,
    required this.kind,
    required this.colors,
  });

  final ExportReport report;
  final _SlideKind kind;
  final List<Color> colors;

  static const double width = 360;
  static const double height = 640;

  Widget _blob(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: alpha),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
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
              Positioned(top: -60, right: -60, child: _blob(240, 0.08)),
              Positioned(bottom: 80, left: -80, child: _blob(220, 0.06)),
              Positioned(top: 260, right: 30, child: _blob(70, 0.08)),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 26, 28, 0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text('DafMoney', style: _ts(13, weight: FontWeight.w800)),
                        const Spacer(),
                        Text(
                          'Kilas ${report.periodLabel}',
                          style: _ts(12, alpha: 0.85),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _slideFor(kind, report, forImage: true)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _ts(
  double size, {
  FontWeight weight = FontWeight.w600,
  double alpha = 1,
  double? spacing,
  double? height,
}) => GoogleFonts.plusJakartaSans(
  fontSize: size,
  fontWeight: weight,
  color: Colors.white.withValues(alpha: alpha),
  letterSpacing: spacing,
  height: height,
  decoration: TextDecoration.none,
);

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.controller,
    required this.count,
    required this.index,
    required this.onClose,
    required this.onShare,
  });

  final AnimationController controller;
  final int count;
  final int index;
  final VoidCallback onClose;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: 3,
                      child: i < index
                          ? const ColoredBox(color: Colors.white)
                          : i > index
                          ? ColoredBox(
                              color: Colors.white.withValues(alpha: 0.28),
                            )
                          : AnimatedBuilder(
                              animation: controller,
                              builder: (_, __) => LinearProgressIndicator(
                                value: controller.value,
                                minHeight: 3,
                                color: Colors.white,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.28,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text('DafMoney', style: _ts(13, weight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                tooltip: 'Bagikan slide ini',
                onPressed: onShare,
                icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FloatingBubbles extends StatelessWidget {
  const _FloatingBubbles();

  @override
  Widget build(BuildContext context) {
    Widget bubble(double size, double alpha, Duration d, double dy) =>
        Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: alpha),
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(begin: -dy, end: dy, duration: d, curve: Curves.easeInOut);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: bubble(240, 0.08, 4.seconds, 18),
          ),
          Positioned(
            bottom: 80,
            left: -80,
            child: bubble(220, 0.06, 5.seconds, 22),
          ),
          Positioned(
            top: 260,
            right: 30,
            child: bubble(70, 0.08, 3.seconds, 14),
          ),
        ],
      ),
    );
  }
}

String? _deltaText(int current, int? previous, String? label) {
  if (previous == null || previous <= 0 || label == null) return null;
  final pct = ((current - previous) / previous * 100).round();
  if (pct == 0) return 'Sama seperti $label';
  return pct > 0 ? 'Naik $pct% dari $label' : 'Turun ${-pct}% dari $label';
}

class _CountUp extends StatelessWidget {
  const _CountUp({
    required this.value,
    required this.style,
    this.delay = Duration.zero,
    this.prefix = '',
  });

  final int value;
  final TextStyle style;
  final Duration delay;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text('$prefix${Fmt.rupiah(v.round())}', style: style),
      ),
    ).animate(delay: delay).fadeIn(duration: 300.ms);
  }
}

class _SlideFrame extends StatelessWidget {
  const _SlideFrame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: math.max(0, c.maxHeight - 40)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _IntroSlide extends StatelessWidget {
  const _IntroSlide({required this.report, this.forImage = false});

  final ExportReport report;
  final bool forImage;

  @override
  Widget build(BuildContext context) {
    return _SlideFrame(
      children: [
        Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 42,
                color: Colors.white,
              ),
            )
            .animate()
            .scale(
              begin: const Offset(0.2, 0.2),
              duration: 800.ms,
              curve: Curves.elasticOut,
            )
            .fadeIn(duration: 300.ms),
        const SizedBox(height: 28),
        Text(
              report.scope == ExportScope.year ? 'Kilas Tahun' : 'Kilas Bulan',
              style: _ts(16, alpha: 0.85, spacing: 1.2),
            )
            .animate()
            .fadeIn(delay: 250.ms, duration: 400.ms)
            .slideY(begin: 0.4, curve: Curves.easeOutCubic),
        const SizedBox(height: 6),
        Text(
              report.periodLabel,
              style: _ts(
                44,
                weight: FontWeight.w800,
                spacing: -1.5,
                height: 1.05,
              ),
            )
            .animate()
            .fadeIn(delay: 380.ms, duration: 500.ms)
            .slideY(begin: 0.35, curve: Curves.easeOutCubic),
        const SizedBox(height: 14),
        Text(
          report.scope == ExportScope.year
              ? 'Yuk lihat ke mana uangmu pergi tahun ini.'
              : 'Yuk lihat ke mana uangmu pergi bulan ini.',
          style: _ts(16, alpha: 0.85, weight: FontWeight.w500, height: 1.4),
        ).animate().fadeIn(delay: 650.ms, duration: 500.ms),
        if (!forImage) ...[
          const SizedBox(height: 40),
          Text('Ketuk untuk lanjut', style: _ts(12, alpha: 0.65))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fade(begin: 0.35, end: 1, duration: 900.ms),
        ],
      ],
    );
  }
}

class _TotalsSlide extends StatelessWidget {
  const _TotalsSlide({required this.report});

  final ExportReport report;

  @override
  Widget build(BuildContext context) {
    final maxV = math.max(1, math.max(report.income, report.expense));

    Widget row(
      String label,
      int value,
      double ratio,
      int delayMs, {
      String? delta,
    }) {
      return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: _ts(14, alpha: 0.8)),
              const SizedBox(height: 4),
              _CountUp(
                value: value,
                delay: Duration(milliseconds: delayMs),
                style: _ts(34, weight: FontWeight.w800, spacing: -1),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 10,
                  child: Stack(
                    children: [
                      ColoredBox(
                        color: Colors.white.withValues(alpha: 0.2),
                        child: const SizedBox.expand(),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: ratio),
                        duration: Duration(milliseconds: 900 + delayMs),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => FractionallySizedBox(
                          widthFactor: v.clamp(0.0, 1.0).toDouble(),
                          child: const ColoredBox(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (delta != null) ...[
                const SizedBox(height: 8),
                Text(delta, style: _ts(12, alpha: 0.8, weight: FontWeight.w600)),
              ],
            ],
          )
          .animate()
          .fadeIn(delay: Duration(milliseconds: delayMs))
          .slideY(
            begin: 0.25,
            delay: Duration(milliseconds: delayMs),
            curve: Curves.easeOutCubic,
          );
    }

    final net = report.net;
    return _SlideFrame(
      children: [
        Text(
          report.scope == ExportScope.year ? 'Tahun ini kamu' : 'Bulan ini kamu',
          style: _ts(18, alpha: 0.9),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 26),
        row(
          'Menerima',
          report.income,
          report.income / maxV,
          150,
          delta: _deltaText(report.income, report.prevIncome, report.prevLabel),
        ),
        const SizedBox(height: 26),
        row(
          'Membelanjakan',
          report.expense,
          report.expense / maxV,
          400,
          delta: _deltaText(
            report.expense,
            report.prevExpense,
            report.prevLabel,
          ),
        ),
        const SizedBox(height: 30),
        Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                net >= 0
                    ? 'Sisa ${Fmt.rupiah(net)}'
                    : 'Defisit ${Fmt.rupiah(-net)}',
                style: _ts(15, weight: FontWeight.w800),
              ),
            )
            .animate()
            .fadeIn(delay: 900.ms, duration: 400.ms)
            .scale(
              begin: const Offset(0.8, 0.8),
              delay: 900.ms,
              curve: Curves.easeOutBack,
            ),
      ],
    );
  }
}

class _CategoriesSlide extends StatelessWidget {
  const _CategoriesSlide({required this.report});

  final ExportReport report;

  @override
  Widget build(BuildContext context) {
    final top = report.expenseCategories.take(3).toList();
    final maxRatio = top.first.ratio == 0 ? 1.0 : top.first.ratio;

    return _SlideFrame(
      children: [
        Text(
          'Uangmu paling banyak mengalir ke',
          style: _ts(18, alpha: 0.9),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 28),
        for (var i = 0; i < top.length; i++) ...[
          if (i > 0) const SizedBox(height: 22),
          _CategoryBar(
            rank: i + 1,
            category: top[i],
            fraction: top[i].ratio / maxRatio,
            delayMs: 200 + i * 220,
          ),
        ],
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.rank,
    required this.category,
    required this.fraction,
    required this.delayMs,
  });

  final int rank;
  final ExportCategory category;
  final double fraction;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    final first = rank == 1;
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '#$rank',
                  style: _ts(
                    first ? 18 : 14,
                    alpha: 0.7,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ts(
                      first ? 30 : 20,
                      weight: FontWeight.w800,
                      spacing: -0.6,
                    ),
                  ),
                ),
                Text(
                  '${(category.ratio * 100).round()}%',
                  style: _ts(first ? 20 : 16, weight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(Fmt.rupiah(category.total), style: _ts(14, alpha: 0.85)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: first ? 12 : 8,
                child: Stack(
                  children: [
                    ColoredBox(
                      color: Colors.white.withValues(alpha: 0.2),
                      child: const SizedBox.expand(),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: fraction),
                      duration: Duration(milliseconds: 900 + delayMs),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => FractionallySizedBox(
                        widthFactor: v.clamp(0.0, 1.0).toDouble(),
                        child: const ColoredBox(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delayMs))
        .slideX(
          begin: -0.12,
          delay: Duration(milliseconds: delayMs),
          curve: Curves.easeOutCubic,
        );
  }
}

class _WeeksSlide extends StatelessWidget {
  const _WeeksSlide({required this.report});

  final ExportReport report;

  @override
  Widget build(BuildContext context) {
    final buckets = report.buckets;
    var maxIdx = 0;
    for (var i = 1; i < buckets.length; i++) {
      if (buckets[i].expense > buckets[maxIdx].expense) maxIdx = i;
    }
    final peak = buckets[maxIdx];
    final maxV = math.max(1, peak.expense);

    return _SlideFrame(
      children: [
        Text(
          'Pengeluaran terbesar ada di',
          style: _ts(18, alpha: 0.9),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 10),
        Text(
              report.scope == ExportScope.year
                  ? 'Bulan ${peak.label}'
                  : 'Tanggal ${peak.label}',
              style: _ts(38, weight: FontWeight.w800, spacing: -1.2),
            )
            .animate()
            .fadeIn(delay: 200.ms, duration: 450.ms)
            .slideY(begin: 0.3, curve: Curves.easeOutCubic),
        const SizedBox(height: 4),
        _CountUp(
          value: peak.expense,
          delay: 350.ms,
          style: _ts(22, weight: FontWeight.w700, alpha: 0.95),
        ),
        const SizedBox(height: 36),
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < buckets.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: buckets.length > 7 ? 2 : 4,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end: buckets[i].expense / maxV,
                              ),
                              duration: Duration(milliseconds: 800 + i * 120),
                              curve: Curves.easeOutBack,
                              builder: (_, v, __) => FractionallySizedBox(
                                heightFactor: v.clamp(0.02, 1.0).toDouble(),
                                widthFactor: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: i == maxIdx
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          buckets[i].label,
                          maxLines: 1,
                          style: _ts(
                            10,
                            alpha: i == maxIdx ? 1 : 0.7,
                            weight: i == maxIdx
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BiggestSlide extends StatelessWidget {
  const _BiggestSlide({required this.report});

  final ExportReport report;

  @override
  Widget build(BuildContext context) {
    ExportEntry? big;
    for (final e in report.entries) {
      if (e.type == EntryType.expense &&
          (big == null || e.amount > big.amount)) {
        big = e;
      }
    }
    final e = big!;

    return _SlideFrame(
      children: [
        Text(
          'Satu pengeluaran paling besar',
          style: _ts(18, alpha: 0.9),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 24),
        Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 34),
                  const SizedBox(height: 12),
                  _CountUp(
                    value: e.amount,
                    delay: 300.ms,
                    style: _ts(38, weight: FontWeight.w800, spacing: -1.2),
                  ),
                  const SizedBox(height: 8),
                  Text(e.categoryName, style: _ts(20, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    Fmt.dateShort(e.date),
                    style: _ts(14, alpha: 0.8, weight: FontWeight.w500),
                  ),
                  if (e.note.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      e.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _ts(14, alpha: 0.85, weight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            )
            .animate()
            .fadeIn(delay: 150.ms, duration: 400.ms)
            .scale(
              begin: const Offset(0.85, 0.85),
              delay: 150.ms,
              duration: 600.ms,
              curve: Curves.easeOutBack,
            ),
      ],
    );
  }
}

class _OutroSlide extends StatelessWidget {
  const _OutroSlide({
    required this.report,
    this.forImage = false,
    this.onShare,
    this.onDone,
  });

  final ExportReport report;
  final bool forImage;
  final VoidCallback? onShare;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final rate = report.savingsRate;
    final shown = (rate ?? 0).clamp(0.0, 1.0).toDouble();
    final yearly = report.scope == ExportScope.year;
    final thisUnit = yearly ? 'tahun ini' : 'bulan ini';
    final nextUnit = yearly ? 'tahun depan' : 'bulan depan';
    final message = rate == null
        ? 'Belum ada pemasukan tercatat $thisUnit.'
        : rate >= 0.2
        ? 'Keren! Kamu berhasil menyisihkan sebagian besar pemasukanmu.'
        : rate >= 0
        ? 'Sudah baik. Coba sisihkan sedikit lebih banyak $nextUnit.'
        : 'Pengeluaran $thisUnit melebihi pemasukan. Semoga $nextUnit lebih baik!';

    return _SlideFrame(
      children: [
        Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: shown),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => SizedBox(
                  width: 190,
                  height: 190,
                  child: CustomPaint(
                    painter: _RingPainter(v),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rate == null ? '-' : '${(v * 100).round()}%',
                            style: _ts(
                              44,
                              weight: FontWeight.w800,
                              spacing: -1.5,
                            ),
                          ),
                          Text('ditabung', style: _ts(13, alpha: 0.8)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
            .animate()
            .fadeIn(duration: 400.ms)
            .scale(
              begin: const Offset(0.8, 0.8),
              duration: 600.ms,
              curve: Curves.easeOutBack,
            ),
        const SizedBox(height: 28),
        Text(message, style: _ts(17, weight: FontWeight.w600, height: 1.4))
            .animate()
            .fadeIn(delay: 500.ms, duration: 500.ms)
            .slideY(begin: 0.2, curve: Curves.easeOutCubic),
        const SizedBox(height: 8),
        Text(
          'Rata-rata pengeluaran ${Fmt.rupiah(report.avgDailyExpense)} per hari.',
          style: _ts(13, alpha: 0.8, weight: FontWeight.w500),
        ).animate().fadeIn(delay: 700.ms, duration: 500.ms),
        if (!forImage) ...[
        const SizedBox(height: 32),
        Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                    ),
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('Bagikan'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    onPressed: onDone,
                    child: const Text('Selesai'),
                  ),
                ),
              ],
            )
            .animate()
            .fadeIn(delay: 900.ms, duration: 400.ms)
            .slideY(begin: 0.3, delay: 900.ms, curve: Curves.easeOutCubic),
        ],
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
