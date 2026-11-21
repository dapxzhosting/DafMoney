import 'package:flutter/material.dart';

/// Container cabang untuk StatefulShellRoute yang memberi transisi
/// fade + geser tipis saat pindah tab. Semua cabang tetap hidup (state
/// terjaga), tab yang tidak aktif disembunyikan dan tickernya dimatikan.
class FadeThroughBranches extends StatelessWidget {
  const FadeThroughBranches({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          _BranchFade(active: i == currentIndex, child: children[i]),
      ],
    );
  }
}

class _BranchFade extends StatefulWidget {
  const _BranchFade({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_BranchFade> createState() => _BranchFadeState();
}

class _BranchFadeState extends State<_BranchFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: widget.active ? 1 : 0,
  );

  late final Animation<double> _curve = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.025),
    end: Offset.zero,
  ).animate(_curve);

  @override
  void didUpdateWidget(_BranchFade old) {
    super.didUpdateWidget(old);
    if (widget.active != old.active) {
      widget.active ? _c.forward() : _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        return TickerMode(
          enabled: widget.active || _c.isAnimating,
          child: Offstage(
            offstage: _c.isDismissed,
            child: IgnorePointer(
              ignoring: !widget.active,
              child: FadeTransition(
                opacity: _curve,
                child: SlideTransition(position: _slide, child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}
