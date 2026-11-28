import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_status_provider.dart';
import '../router/app_router.dart';
import '../router/app_routes.dart';

/// Pil kecil "Menunggu sinkron" di semua halaman selain dashboard
/// (dashboard sudah punya SyncStatusBanner sendiri).
class GlobalSyncPill extends ConsumerStatefulWidget {
  const GlobalSyncPill({super.key});

  @override
  ConsumerState<GlobalSyncPill> createState() => _GlobalSyncPillState();
}

class _GlobalSyncPillState extends ConsumerState<GlobalSyncPill> {
  Timer? _timer;
  bool _show = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onPending(bool pending) {
    _timer?.cancel();
    if (pending) {
      _timer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _show = true);
      });
    } else if (_show) {
      setState(() => _show = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(pendingSyncAnyProvider, (_, next) {
      _onPending(next.valueOrNull ?? false);
    });
    final router = ref.watch(routerProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        final path = router.routerDelegate.currentConfiguration.uri.path;
        if (!_show || path == AppRoutes.dashboard) {
          return const SizedBox.shrink();
        }
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Material(
                  color: cs.secondaryContainer,
                  shape: const StadiumBorder(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 16,
                          color: cs.onSecondaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Menunggu sinkron',
                          style: tt.labelMedium?.copyWith(
                            color: cs.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
