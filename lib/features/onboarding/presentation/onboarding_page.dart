import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/onboarding_provider.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';

class _Slide {
  const _Slide({
    required this.icon,
    required this.title,
    required this.message,
    required this.floating,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<IconData> floating;
}

const _slides = [
  _Slide(
    icon: Icons.receipt_long_rounded,
    title: 'Catat dalam hitungan detik',
    message: 'Tambah pemasukan dan pengeluaran dengan cepat, lengkap dengan kategori dan catatan.',
    floating: [
      Icons.arrow_downward_rounded,
      Icons.arrow_upward_rounded,
      Icons.add_rounded,
    ],
  ),
  _Slide(
    icon: Icons.account_balance_wallet_rounded,
    title: 'Atur dompet & anggaran',
    message: 'Pisahkan saldo tunai, rekening bank, dan dompet digital, lalu pasang batas pengeluaran per kategori.',
    floating: [
      Icons.pie_chart_rounded,
      Icons.savings_rounded,
      Icons.payments_rounded,
    ],
  ),
  _Slide(
    icon: Icons.insert_chart_rounded,
    title: 'Pahami ke mana uangmu pergi',
    message: 'Lihat grafik dan laporan bulanan untuk menemukan kebiasaan yang bisa dihemat.',
    floating: [
      Icons.trending_up_rounded,
      Icons.bar_chart_rounded,
      Icons.donut_large_rounded,
    ],
  ),
];

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == _slides.length - 1;

  Future<void> _finish() async {
    HapticFeedback.lightImpact();
    await ref.read(onboardingDoneProvider.notifier).complete();
    if (mounted) context.go(AppRoutes.dashboard);
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    HapticFeedback.selectionClick();
    _controller.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Gap.maxContentWidth),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.page,
                      Gap.xs,
                      Gap.sm,
                      0,
                    ),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isLast ? 0 : 1,
                      child: TextButton(
                        onPressed: _isLast ? null : _finish,
                        child: const Text('Lewati'),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _page = i);
                    },
                    itemBuilder: (_, i) =>
                        _SlideView(slide: _slides[i], active: i == _page),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _slides.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page ? cs.primary : cs.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(Gap.page),
                  child: FilledButton(
                    onPressed: _next,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _isLast ? 'Mulai sekarang' : 'Lanjut',
                        key: ValueKey(_isLast),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.active});

  final _Slide slide;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final target = active ? 1.0 : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Illustration(slide: slide, active: active),
          const SizedBox(height: Gap.lg),
          Text(
                slide.title,
                textAlign: TextAlign.center,
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              )
              .animate(autoPlay: false, target: target)
              .fadeIn(duration: 400.ms, delay: 150.ms)
              .slideY(begin: 0.3, curve: Curves.easeOutCubic),
          const SizedBox(height: Gap.sm),
          Text(
                slide.message,
                textAlign: TextAlign.center,
                style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
              )
              .animate(autoPlay: false, target: target)
              .fadeIn(duration: 400.ms, delay: 280.ms)
              .slideY(begin: 0.3, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.slide, required this.active});

  final _Slide slide;
  final bool active;

  static const _positions = [
    Alignment(-0.85, -0.55),
    Alignment(0.9, -0.2),
    Alignment(-0.45, 0.9),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final target = active ? 1.0 : 0.0;
    final tints = [cs.tertiaryContainer, cs.secondaryContainer, cs.primary];
    final onTints = [
      cs.onTertiaryContainer,
      cs.onSecondaryContainer,
      cs.onPrimary,
    ];

    return SizedBox(
      width: 280,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primaryContainer.withValues(alpha: 0.35),
                ),
              )
              .animate(autoPlay: false, target: target)
              .scale(
                begin: const Offset(0.6, 0.6),
                duration: 600.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(),
          Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primaryContainer.withValues(alpha: 0.7),
                ),
              )
              .animate(autoPlay: false, target: target)
              .scale(
                begin: const Offset(0.5, 0.5),
                duration: 600.ms,
                delay: 100.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(delay: 100.ms),
          Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary,
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Icon(slide.icon, size: 52, color: cs.onPrimary),
              )
              .animate(autoPlay: false, target: target)
              .scale(
                begin: const Offset(0.3, 0.3),
                duration: 650.ms,
                delay: 200.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(delay: 200.ms),
          for (var i = 0; i < slide.floating.length; i++)
            Align(
              alignment: _positions[i],
              child:
                  Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: tints[i],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          slide.floating[i],
                          size: 24,
                          color: onTints[i],
                        ),
                      )
                      .animate(autoPlay: false, target: target)
                      .scale(
                        begin: Offset.zero,
                        duration: 500.ms,
                        delay: (350 + i * 120).ms,
                        curve: Curves.easeOutBack,
                      )
                      .fadeIn(delay: (350 + i * 120).ms),
            ),
        ],
      ),
    );
  }
}
