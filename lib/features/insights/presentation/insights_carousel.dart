import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/section_header.dart';
import '../domain/insight_engine.dart';

class InsightsCarousel extends StatefulWidget {
  const InsightsCarousel({
    super.key,
    required this.insights,
    required this.storyTitle,
    required this.onOpenStory,
    required this.onShareInsight,
    this.yearTitle,
    this.onOpenYearStory,
  });

  final List<Insight> insights;
  final String storyTitle;
  final VoidCallback onOpenStory;
  final void Function(Insight insight) onShareInsight;
  final String? yearTitle;
  final VoidCallback? onOpenYearStory;

  @override
  State<InsightsCarousel> createState() => _InsightsCarouselState();
}

class _InsightsCarouselState extends State<InsightsCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _page = 0;
  DateTime _lastTouch = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _hasYear =>
      widget.onOpenYearStory != null && widget.yearTitle != null;

  int get _count => widget.insights.length + 1 + (_hasYear ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _autoAdvance());
  }

  void _autoAdvance() {
    if (!mounted || !_controller.hasClients) return;
    if (!TickerMode.of(context)) return;
    if (DateTime.now().difference(_lastTouch) < const Duration(seconds: 8)) {
      return;
    }
    final next = (_page + 1) % _count;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(InsightsCarousel old) {
    super.didUpdateWidget(old);
    if (old.insights.length != widget.insights.length) {
      _page = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Wawasan'),
        const SizedBox(height: Gap.xs),
        Transform.translate(
          offset: const Offset(0, 0),
          child: SizedBox(
            height: 128,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollStartNotification && n.dragDetails != null) {
                  _lastTouch = DateTime.now();
                }
                return false;
              },
              child: PageView.builder(
                controller: _controller,
                padEnds: false,
                clipBehavior: Clip.none,
                itemCount: _count,
                onPageChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _page = i);
                },
                itemBuilder: (_, i) {
                  return AnimatedBuilder(
                        animation: _controller,
                        builder: (_, child) {
                          var dist = 0.0;
                          if (_controller.hasClients &&
                              _controller.position.haveDimensions) {
                            dist = ((_controller.page ?? _page.toDouble()) - i)
                                .abs()
                                .clamp(0.0, 1.0)
                                .toDouble();
                          } else {
                            dist = i == 0 ? 0 : 1;
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: Gap.xs),
                            child: Transform.scale(
                              scale: 1 - 0.05 * dist,
                              child: Opacity(
                                opacity: 1 - 0.25 * dist,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: i == 0
                            ? _StoryCard(
                                title: widget.storyTitle,
                                onTap: widget.onOpenStory,
                              )
                            : _hasYear && i == _count - 1
                            ? _StoryCard(
                                title: widget.yearTitle!,
                                subtitle:
                                    'Lihat perjalanan keuanganmu setahun penuh.',
                                colors: const [
                                  Color(0xFF0891B2),
                                  Color(0xFF1E1B4B),
                                ],
                                onTap: widget.onOpenYearStory!,
                              )
                            : _InsightCard(
                                insight: widget.insights[i - 1],
                                onShare: () {
                                  HapticFeedback.lightImpact();
                                  widget.onShareInsight(widget.insights[i - 1]);
                                },
                              ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: (90 * i).ms)
                      .slideX(
                        begin: 0.12,
                        duration: 450.ms,
                        delay: (90 * i).ms,
                        curve: Curves.easeOutCubic,
                      );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? cs.primary : cs.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.colors, required this.child, this.onTap});

  final List<Color> colors;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned(
                  right: -30,
                  top: -30,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                ),
                Positioned(
                  right: 30,
                  bottom: -40,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                ),
                Padding(padding: const EdgeInsets.all(Gap.md), child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight, required this.onShare});

  final Insight insight;
  final VoidCallback onShare;

  static List<Color> _colors(InsightTone t) {
    switch (t) {
      case InsightTone.good:
        return const [Color(0xFF10B981), Color(0xFF047857)];
      case InsightTone.warn:
        return const [Color(0xFFF59E0B), Color(0xFFDC2626)];
      case InsightTone.info:
        return const [Color(0xFF3B82F6), Color(0xFF6366F1)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return _CardShell(
      colors: _colors(insight.tone),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            child: Icon(insight.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Bagikan sebagai gambar',
            visualDensity: VisualDensity.compact,
            onPressed: onShare,
            icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.title,
    required this.onTap,
    this.subtitle = 'Lihat ringkasan bulanmu dalam cerita singkat.',
    this.colors = const [Color(0xFF8B5CF6), Color(0xFFDB2777)],
  });

  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return _CardShell(
          colors: colors,
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Row(
            children: [
              Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.1, 1.1),
                    duration: 1200.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: tt.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 30,
              ),
            ],
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 2200.ms,
          delay: 1800.ms,
          color: Colors.white.withValues(alpha: 0.28),
        );
  }
}
