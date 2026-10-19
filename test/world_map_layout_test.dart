import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/campaign/data/legacy_region_catalog.dart';
import 'package:kvm/features/garden/presentation/garden_screens.dart';

const _actionKeys = ['world-review', 'world-explore', 'world-traces'];

Widget _host({
  required double scale,
  EdgeInsets padding = EdgeInsets.zero,
  VoidCallback? onReview,
  VoidCallback? onExplore,
  VoidCallback? onRestore,
  ValueChanged<String>? onSelectRegion,
  String? statusMessage,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(scale), padding: padding),
    child: child!,
  ),
  home: WorldMapScreen(
    unlockedRegionIds: const {'region-01-calculation', 'region-02-pattern'},
    restoredNodeIds: const {},
    totalStars: 90,
    weeklyActions: 3,
    onReview: onReview,
    onExplore: onExplore,
    onRestore: onRestore,
    onSelectRegion: onSelectRegion ?? (_) {},
    onSettings: () {},
    onCompanions: () {},
    reviewDetail: '오늘 돌아온 개념 1개',
    explorationDetail: '저장된 탐험 이어가기',
    statusMessage: statusMessage,
  ),
);

void _expectReachableMap(WidgetTester tester, Size size) {
  final bounds = Offset.zero & size;
  final actions = <Rect>[];
  for (final key in _actionKeys) {
    final rect = tester.getRect(find.byKey(ValueKey(key)));
    expect(rect.height, greaterThanOrEqualTo(44));
    expect(rect.width, greaterThanOrEqualTo(44));
    expect(bounds.intersect(rect), rect, reason: '$key outside viewport');
    actions.add(rect);
  }
  for (final region in legacyRegionCatalog) {
    final marker = find.byKey(ValueKey('world-region-${region.id}'));
    final rect = tester.getRect(marker);
    expect(
      bounds.intersect(rect),
      rect,
      reason: '${region.id} outside viewport',
    );
    for (final action in actions) {
      expect(
        rect.overlaps(action),
        isFalse,
        reason: '${region.id} hidden by a floating action at $size',
      );
    }
  }
  expect(find.text('업데이트 예정'), findsNWidgets(5));
  expect(tester.takeException(), isNull);
}

void main() {
  for (final size in const [
    Size(800, 360),
    Size(720, 320),
    Size(680, 300),
    Size(960, 432),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('floating map $size text $scale stays unobstructed', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          _host(
            scale: scale,
            onReview: () {},
            onExplore: () {},
            onRestore: () {},
          ),
        );
        await tester.pumpAndSettle();
        _expectReachableMap(tester, size);

        // Compare with the removed full-width cards at identical viewports.
        final contentHeight = size.height - 48;
        final oldCardHeight = scale > 1 ? 80 : (contentHeight < 330 ? 66 : 78);
        final oldMapHeight = contentHeight - oldCardHeight - 15;
        final oldImage = applyBoxFit(
          BoxFit.contain,
          const Size(6000, 2413),
          Size(size.width - 20, oldMapHeight),
        ).destination;
        final image = tester.getSize(
          find.byKey(const ValueKey('world-map-artwork')),
        );
        expect(image.width, greaterThan(oldImage.width * 1.25));
        expect(image.width / image.height, closeTo(6000 / 2413, .0001));
      });
    }
  }

  for (final scale in [1.0, 1.3]) {
    for (final padding in const [
      EdgeInsets.fromLTRB(20, 10, 20, 10),
      EdgeInsets.fromLTRB(24, 24, 0, 20),
    ]) {
      testWidgets('safe area $padding text $scale keeps map actions clear', (
        tester,
      ) async {
        const size = Size(720, 320);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          _host(
            scale: scale,
            padding: padding,
            statusMessage: '저장 확인이 필요합니다. 설정에서 저장 상태를 확인하세요.',
            onReview: () {},
            onExplore: () {},
            onRestore: () {},
          ),
        );
        await tester.pumpAndSettle();
        _expectReachableMap(tester, size);
        expect(find.textContaining('저장 확인이 필요합니다'), findsOneWidget);
      });
    }
  }

  testWidgets('floating actions preserve navigation and accessible details', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final calls = <String>[];
      await tester.pumpWidget(
        _host(
          scale: 1,
          onReview: () => calls.add('review'),
          onExplore: () => calls.add('explore'),
          onRestore: () => calls.add('restore'),
          onSelectRegion: (id) => calls.add(id),
        ),
      );
      await tester.pumpAndSettle();
      for (final key in _actionKeys) {
        await tester.tap(find.byKey(ValueKey(key)));
      }
      for (final region in legacyRegionCatalog) {
        await tester.tap(find.byKey(ValueKey('world-region-${region.id}')));
      }
      expect(calls, [
        'review',
        'explore',
        'restore',
        ...legacyRegionCatalog.map((r) => r.id),
      ]);
      final explore = tester.getSemantics(
        find.byKey(const ValueKey('world-explore')),
      );
      expect(explore.label, contains('저장된 탐험 이어가기'));
      expect(explore.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      await tester.longPress(find.byKey(const ValueKey('world-explore')));
      await tester.pumpAndSettle();
      expect(find.textContaining('저장된 탐험 이어가기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('unavailable floating actions remain disabled', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_host(scale: 1));
      await tester.pumpAndSettle();
      for (final key in _actionKeys) {
        final node = tester.getSemantics(find.byKey(ValueKey(key)));
        expect(node.flagsCollection.isEnabled, Tristate.isFalse);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      }
      await tester.longPress(find.byKey(const ValueKey('world-traces')));
      await tester.pumpAndSettle();
      expect(find.textContaining('이번 주 3/5번의 발걸음'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
