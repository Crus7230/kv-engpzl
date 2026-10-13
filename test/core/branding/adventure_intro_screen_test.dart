import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/core/branding/adventure_intro_screen.dart';

Widget _intro({bool reducedMotion = false, String status = '탐험을 준비하고 있어요'}) =>
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.3),
          disableAnimations: reducedMotion,
        ),
        child: child!,
      ),
      home: AdventureIntroScreen(status: status),
    );

void main() {
  for (final size in const [
    Size(800, 360),
    Size(680, 300),
    Size(480, 216),
    Size(960, 432),
  ]) {
    testWidgets('intro fits $size at 130% text without an image pack', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_intro());
      await tester.pumpAndSettle();
      expect(find.text('KV 수학탐험대'), findsOneWidget);
      expect(find.text('탐험을 준비하고 있어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  }

  testWidgets('reduced motion is static and status changes are announced', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_intro(reducedMotion: true));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(
        _intro(reducedMotion: true, status: '지난 탐험 기록을 불러오고 있어요'),
      );
      await tester.pump();
      final status = tester.getSemantics(
        find.bySemanticsLabel('지난 탐험 기록을 불러오고 있어요'),
      );
      expect(status.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    }
  });
}
