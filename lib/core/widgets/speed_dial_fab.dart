import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'motion.dart';

class SpeedDialAction {
  const SpeedDialAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class SpeedDialFab extends StatelessWidget {
  const SpeedDialFab({
    super.key,
    required this.open,
    required this.extended,
    required this.onToggle,
    required this.actions,
    this.label = 'Transaksi',
  });

  final bool open;
  final bool extended;
  final VoidCallback onToggle;
  final List<SpeedDialAction> actions;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < actions.length; i++)
          IgnorePointer(
            ignoring: !open,
            child:
                Padding(
                      padding: const EdgeInsets.only(bottom: 14, right: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: cs.surfaceContainerHighest,
                            elevation: 3,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              child: Text(
                                actions[i].label,
                                style: tt.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FloatingActionButton.small(
                            heroTag: null,
                            elevation: 3,
                            backgroundColor: actions[i].color,
                            foregroundColor: Colors.white,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              actions[i].onTap();
                            },
                            child: Icon(actions[i].icon),
                          ),
                        ],
                      ),
                    )
                    .animate(
                      autoPlay: false,
                      target: open ? 1 : 0,
                      delay: Duration(
                        milliseconds: (actions.length - 1 - i) * 60,
                      ),
                    )
                    .fadeIn(duration: 200.ms)
                    .slideY(
                      begin: 0.8,
                      end: 0,
                      duration: 280.ms,
                      curve: Curves.easeOutBack,
                    )
                    .scale(
                      begin: const Offset(0.7, 0.7),
                      end: const Offset(1, 1),
                      duration: 280.ms,
                      curve: Curves.easeOutBack,
                    ),
          ),
        FloatingActionButton.extended(
          heroTag: null,
          onPressed: () {
            HapticFeedback.selectionClick();
            onToggle();
          },
          isExtended: extended,
          icon: AnimatedRotation(
            turns: open ? 0.125 : 0,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            child: const Icon(Icons.add_rounded),
          ),
          label: SwapText(open ? 'Tutup' : label),
        ),
      ],
    );
  }
}
