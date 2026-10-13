import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/core/layout/landscape_game_viewport.dart';

Future<void> _mount(
  WidgetTester tester, {
  required Size size,
  EdgeInsets padding = EdgeInsets.zero,
  required Widget child,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, navigator) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(padding: padding, viewPadding: padding),
        child: LandscapeGameViewport(child: navigator!),
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('regular landscape phones keep their existing canvas', () {
    for (final size in const [
      Size(800, 360),
      Size(720, 320),
      Size(680, 300),
      Size(960, 432),
      Size(480, 270),
    ]) {
      expect(LandscapeGameViewport.fit(size), size);
    }
  });

  for (final (size, expected) in const [
    (Size(900, 700), Size(900, 405)),
    (Size(1280, 800), Size(960, 432)),
    (Size(960, 960), Size(960, 432)),
  ]) {
    testWidgets('tall screen $size uses a centered $expected canvas', (
      tester,
    ) async {
      Size? logicalSize;
      await _mount(
        tester,
        size: size,
        child: Builder(
          builder: (context) {
            logicalSize = MediaQuery.sizeOf(context);
            return const Scaffold(body: Text('game'));
          },
        ),
      );
      final bounds = tester.getRect(find.byKey(LandscapeGameViewport.frameKey));
      expect(bounds.size, expected);
      expect(bounds.center, Offset(size.width / 2, size.height / 2));
      expect(logicalSize, expected);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('safe area is consumed once and dialogs share the game canvas', (
    tester,
  ) async {
    var taps = 0;
    MediaQueryData? dialogMedia;
    await _mount(
      tester,
      size: const Size(720, 320),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () {
                taps++;
                showDialog<void>(
                  context: context,
                  builder: (context) {
                    dialogMedia = MediaQuery.of(context);
                    return const AlertDialog(title: Text('settings'));
                  },
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(LandscapeGameViewport.frameKey)),
      const Size(680, 300),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(dialogMedia!.size, const Size(680, 300));
    expect(dialogMedia!.padding, EdgeInsets.zero);
    expect(dialogMedia!.viewPadding, EdgeInsets.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets('folding and unfolding does not replace the active screen', (
    tester,
  ) async {
    final state = ValueNotifier<int>(0);
    addTearDown(state.dispose);
    await _mount(
      tester,
      size: const Size(900, 700),
      child: Scaffold(
        body: ValueListenableBuilder<int>(
          valueListenable: state,
          builder: (context, value, _) => Center(
            child: FilledButton(
              onPressed: () => state.value++,
              child: Text('count $value'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('count 0'));
    await tester.pump();
    tester.view.physicalSize = const Size(800, 360);
    await tester.pumpAndSettle();
    expect(find.text('count 1'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(LandscapeGameViewport.frameKey)),
      const Size(800, 360),
    );
    await tester.tap(find.text('count 1'));
    await tester.pump();
    expect(find.text('count 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
