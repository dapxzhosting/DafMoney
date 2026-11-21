import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_images.dart';
import '../../../core/providers/onboarding_provider.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/widgets/motion.dart';

class _Slide {
  const _Slide({
    required this.image,
    required this.title,
    required this.message,
  });

  final String image;
  final String title;
  final String message;
}

const _slides = [
  _Slide(
    image: AppImages.womanDesk,
    title: 'Catat dalam hitungan detik',
    message: 'Tambah pemasukan dan pengeluaran dengan cepat, lengkap dengan kategori dan catatan.',
  ),
  _Slide(
    image: AppImages.moneyBag,
    title: 'Atur dompet & anggaran',
    message: 'Pisahkan saldo tunai, rekening bank, dan dompet digital, lalu pasang batas pengeluaran per kategori.',
  ),
  _Slide(
    image: AppImages.womanChart,
    title: 'Pahami ke mana uangmu pergi',
    message: 'Lihat grafik dan laporan bulanan untuk menemukan kebiasaan yang bisa dihemat.',
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
                    child: SwapText(_isLast ? 'Mulai sekarang' : 'Lanjut'),
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
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
        ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.slide, required this.active});

  final _Slide slide;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final target = active ? 1.0 : 0.0;

    return SizedBox(
      width: 280,
      height: 260,
      child: Center(
        child: Illustration(slide.image, size: 224, tilted: true)
            .animate(autoPlay: false, target: target)
            .scale(
              begin: const Offset(0.7, 0.7),
              duration: 650.ms,
              curve: Curves.easeOutBack,
            )
            .fadeIn(duration: 350.ms),
      ),
    );
  }
}
