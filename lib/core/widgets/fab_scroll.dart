import 'package:flutter/material.dart';

/// Membungkus Scaffold agar FAB bisa mengecil (hanya ikon) saat daftar
/// digulir ke bawah dan melebar lagi saat digulir ke atas.
///
/// Pasang [onScroll] ke `NotificationListener` di body, dan pakai
/// [extended] pada `FloatingActionButton.extended(isExtended: ...)`.
class FabScroll extends StatefulWidget {
  const FabScroll({super.key, required this.builder});

  final Widget Function(
    BuildContext context,
    bool extended,
    NotificationListenerCallback<ScrollNotification> onScroll,
  )
  builder;

  @override
  State<FabScroll> createState() => _FabScrollState();
}

class _FabScrollState extends State<FabScroll> {
  bool _extended = true;

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n is! ScrollUpdateNotification) return false;
    final delta = n.scrollDelta ?? 0;
    final atTop = n.metrics.pixels < 48;
    if ((atTop || delta < -1) && !_extended) {
      setState(() => _extended = true);
    } else if (!atTop && delta > 1 && _extended) {
      setState(() => _extended = false);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _extended, _onScroll);
}
