import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.icon,
    required this.note,
    this.showAppBar = true,
  });

  final String title;
  final IconData icon;
  final String note;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: showAppBar ? AppBar(title: Text(title)) : null,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: cs.onPrimaryContainer),
              )
                  .animate()
                  .scale(duration: 450.ms, curve: Curves.easeOutBack)
                  .fadeIn(),
              const SizedBox(height: 20),
              Text(title,
                      style: tt.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700))
                  .animate()
                  .fadeIn(delay: 120.ms)
                  .slideY(begin: 0.2),
              const SizedBox(height: 6),
              Text(note,
                      style: tt.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant))
                  .animate()
                  .fadeIn(delay: 200.ms),
            ],
          ),
        ),
      ),
    );
  }
}
