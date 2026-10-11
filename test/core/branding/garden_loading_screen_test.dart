import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/core/branding/garden_branding.dart';
import 'package:kvm/core/theme/app_theme.dart';

void _viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _screen({
  String status = '저장된 정원을 열고 있어요',
  double textScale = 1,
  bool reduceMotion = false,
  bool disableAnimations = false,
}) => MaterialApp(
  theme: AppTheme.light(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: child!,
  ),
  home: GardenLoadingScreen(status: status, reduceMotion: reduceMotion),
);

void main() {
  for (final size in const [Size(680, 300), Size(560, 300), Size(360, 640)]) {
    testWidgets('loading layout fits $size at 130 percent text', (
      tester,
    ) async {
      _viewport(tester, size);
      await tester.pumpWidget(_screen(textScale: 1.3));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('KV 수학탐험대'), findsOneWidget);
      expect(find.text('저장된 정원을 열고 있어요'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  }

  testWidgets('entrance settles without keeping preparation alive', (
    tester,
  ) async {
    await tester.pumpWidget(_screen());
    final pumps = await tester.pumpAndSettle();

    expect(pumps, lessThanOrEqualTo(12));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const MaterialApp(home: Text('준비 완료')));
    await tester.pump();
    expect(find.text('준비 완료'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app and system reduced motion suppress entrance animation', (
    tester,
  ) async {
    for (final useSystemSetting in [false, true]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _screen(
          reduceMotion: !useSystemSetting,
          disableAnimations: useSystemSetting,
        ),
      );
      await tester.pump();

      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('status updates are announced as a live region', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_screen(reduceMotion: true));

      expect(
        find.bySemanticsLabel('KV 수학탐험대 로고, 수식 타일에서 자라는 새싹'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        _screen(status: '탐험 기록을 확인하고 있어요', reduceMotion: true),
      );
      await tester.pump();

      final status = tester.getSemantics(
        find.bySemanticsLabel('탐험 기록을 확인하고 있어요'),
      );
      expect(status.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
      expect(find.text('저장된 정원을 열고 있어요'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });
}
