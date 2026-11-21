import 'package:daf_money/core/constants/app_images.dart';
import 'package:daf_money/core/widgets/empty_state.dart';
import 'package:daf_money/core/widgets/illustration.dart';
import 'package:daf_money/features/onboarding/presentation/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Membungkus widget dalam MaterialApp. Sengaja TIDAK memuat DafMoneyApp:
/// aplikasi penuh butuh Firebase dan plugin platform yang tidak ada di
/// `flutter test`, jadi tes yang membootnya gagal di CI.
Widget _host(Widget child, {ThemeMode mode = ThemeMode.light}) {
  return MaterialApp(
    themeMode: mode,
    theme: ThemeData(useMaterial3: true),
    darkTheme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(body: child),
  );
}

void main() {
  group('EmptyState', () {
    testWidgets('memakai ilustrasi bila image diberikan', (tester) async {
      await tester.pumpWidget(
        _host(
          const EmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'Belum ada transaksi',
            message: 'Catat transaksi pertama Anda.',
            image: AppImages.womanDesk,
          ),
        ),
      );

      expect(find.text('Belum ada transaksi'), findsOneWidget);
      expect(find.byType(Illustration), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_rounded), findsNothing);
    });

    testWidgets('memakai ikon bila tanpa ilustrasi', (tester) async {
      await tester.pumpWidget(
        _host(
          const EmptyState(
            icon: Icons.category_rounded,
            title: 'Belum ada kategori',
            message: 'Tambahkan kategori pertama Anda.',
          ),
        ),
      );

      expect(find.text('Belum ada kategori'), findsOneWidget);
      expect(find.byIcon(Icons.category_rounded), findsOneWidget);
      expect(find.byType(Illustration), findsNothing);
    });
  });

  group('Illustration', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('tampil tanpa error di tema ${mode.name}', (tester) async {
        await tester.pumpWidget(
          _host(
            const Center(
              child: Illustration(AppImages.moneyBag, size: 200, tilted: true),
            ),
            mode: mode,
          ),
        );

        expect(find.byType(Illustration), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Onboarding', () {
    testWidgets('menampilkan slide pertama lalu lanjut ke slide kedua', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: OnboardingPage())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Catat dalam hitungan detik'), findsOneWidget);
      expect(find.text('Lewati'), findsOneWidget);
      expect(find.byType(Illustration), findsWidgets);

      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();

      expect(find.text('Atur dompet & anggaran'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
