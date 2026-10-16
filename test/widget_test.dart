import 'package:exp_anim/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checks gestures, controls, and layouts using Flutter's simulated screen.
void main() {
  testWidgets('Pause, scatter and tune the running experiment', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Order in motion.'), findsOneWidget);
    expect(find.textContaining('15.2k particles'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Pause animation'));
    await tester.pump();
    expect(find.byTooltip('Resume animation'), findsOneWidget);

    // Scattering a paused scene resumes the clock.
    await tester.tap(find.text('Scatter'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('Pause animation'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('particle-stage')),
      const Offset(70, 25),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Pause animation'));
    await tester.pump();
    await tester.tap(find.text('Physics'));
    await tester.pumpAndSettle();
    expect(find.text('The shape of a spring.'), findsOneWidget);
    expect(find.byType(Slider), findsNWidgets(3));
    await tester.drag(find.byType(Slider).at(1), const Offset(65, 0));
    await tester.pump();
    await tester.tap(find.text('Try it'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byTooltip('Pause animation'), findsOneWidget);
    expect(find.text('The shape of a spring.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Controls fit a small landscape viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(740, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 32));
    expect(find.text('Scatter'), findsOneWidget);
    expect(find.text('Physics'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
