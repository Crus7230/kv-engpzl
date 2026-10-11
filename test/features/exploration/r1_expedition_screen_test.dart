import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/core/theme/app_theme.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/campaign/domain/campaign_models.dart';
import 'package:kvm/features/companions/presentation/companion_screens.dart';
import 'package:kvm/features/exploration/data/r1_expedition_catalog.dart';
import 'package:kvm/features/exploration/presentation/expedition_milestone_screen.dart';
import 'package:kvm/features/exploration/presentation/r1_expedition_screen.dart';
import 'package:kvm/features/garden/data/garden_catalog.dart';
import 'package:kvm/features/garden/presentation/garden_screens.dart';

final _stages = initialCampaign.regions.first.stages.toList();

R1ExpeditionScreen _screen({
  Set<String> completed = const {},
  Set<String>? unlocked,
  Set<String> restored = const {},
  String? nextStage,
  bool activeSession = false,
  bool canRestore = false,
  bool Function(StageDefinition)? canEnter,
  ValueChanged<String>? onSelect,
  VoidCallback? onPlay,
  VoidCallback? onCompanions,
  String? playerCharacterId = 'CHAR_H',
}) => R1ExpeditionScreen(
  stages: _stages,
  completedStageIds: completed,
  unlockedStageIds: unlocked ?? {_stages.first.id},
  restoredNodeIds: restored,
  decorationChoices: const {},
  nextStageId: nextStage ?? _stages.first.id,
  hasActiveSession: activeSession,
  canRestore: canRestore,
  canEnterStage: canEnter,
  onSelectStage: onSelect ?? (_) {},
  onBack: () {},
  onPlay: onPlay ?? () {},
  onRestore: () {},
  onStories: () {},
  onCompanions: onCompanions ?? () {},
  unlockedCharacterIds: const {'CHAR_D'},
  playerCharacterId: playerCharacterId,
);

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(800, 360),
  double scale = 1,
  EdgeInsets padding = EdgeInsets.zero,
  GlobalKey? boundaryKey,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light().copyWith(
        textTheme: AppTheme.light().textTheme.apply(
          fontFamily: 'KvmPreviewKorean',
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          padding: padding,
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: RepaintBoundary(key: boundaryKey, child: screen),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final font = File(
      Platform.environment['KVM_PREVIEW_FONT'] ??
          r'C:\Windows\Fonts\malgun.ttf',
    );
    if (await font.exists()) {
      final loader = FontLoader('KvmPreviewKorean');
      loader.addFont(
        Future.value(ByteData.sublistView(await font.readAsBytes())),
      );
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final size in const [
    Size(800, 360),
    Size(720, 320),
    Size(680, 300),
    Size(960, 432),
  ]) {
    testWidgets('all ten trail nodes fit $size at 130% text', (tester) async {
      await _pump(tester, _screen(canRestore: true), size: size, scale: 1.3);
      for (final stage in _stages.take(10)) {
        final finder = find.byKey(ValueKey('expedition-stage-${stage.id}'));
        expect(finder, findsOneWidget);
        final bounds = tester.getRect(finder);
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(bounds.bottom, lessThanOrEqualTo(size.height));
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(size.width));
      }
      expect(find.byType(Scrollable), findsNothing);
      expect(
        find.byKey(const ValueKey('expedition-play')).hitTestable(),
        findsOneWidget,
      );
    });
  }

  testWidgets('low safe area remains usable without hiding route controls', (
    tester,
  ) async {
    await _pump(
      tester,
      _screen(canRestore: true),
      size: const Size(720, 320),
      scale: 1.3,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
    );
    expect(
      find.byKey(const ValueKey('expedition-play')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('expedition-companions')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('locked or source-blocked stage cannot dispatch navigation', (
    tester,
  ) async {
    final selected = <String>[];
    await _pump(
      tester,
      _screen(
        unlocked: {_stages.first.id, _stages[1].id},
        canEnter: (stage) => stage.id == _stages.first.id,
        onSelect: selected.add,
      ),
    );
    await tester.tap(find.byKey(ValueKey('expedition-stage-${_stages[1].id}')));
    await tester.tap(find.byKey(ValueKey('expedition-stage-${_stages[2].id}')));
    expect(selected, isEmpty);
    await tester.tap(
      find.byKey(ValueKey('expedition-stage-${_stages.first.id}')),
    );
    expect(selected, [_stages.first.id]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all six destinations preserve stable nodes and review checks', (
    tester,
  ) async {
    final selected = <String>[];
    await _pump(tester, _screen(onSelect: selected.add));
    for (var chapter = 1; chapter <= 6; chapter++) {
      await tester.tap(find.byKey(ValueKey('expedition-chapter-$chapter')));
      await tester.pumpAndSettle();
      final id = 'r01-c${chapter.toString().padLeft(2, '0')}-s01';
      expect(find.byKey(ValueKey('expedition-stage-$id')), findsOneWidget);
      if (chapter != 1) {
        await tester.tap(find.byKey(ValueKey('expedition-stage-$id')));
        expect(selected, isEmpty);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'next stage selects its destination and active resume stays intact',
    (tester) async {
      var resumes = 0;
      var companions = 0;
      await _pump(
        tester,
        _screen(
          nextStage: 'r01-c04-s03',
          activeSession: true,
          onPlay: () => resumes++,
          onCompanions: () => companions++,
        ),
      );
      expect(
        find.byKey(const ValueKey('expedition-stage-r01-c04-s03')),
        findsOneWidget,
      );
      expect(find.text('이어서 탐험하기'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('expedition-play')));
      await tester.tap(find.byKey(const ValueKey('expedition-companions')));
      expect(resumes, 1);
      expect(companions, 1);
    },
  );

  testWidgets(
    'selected H appears on map and briefing without unrescued D or J',
    (tester) async {
      await _pump(tester, _screen(), size: const Size(680, 300), scale: 1.3);
      final mapPortrait = tester.widget<CompanionPortrait>(
        find.byKey(const ValueKey('expedition-player-portrait')),
      );
      expect(mapPortrait.profile.id, 'CHAR_H');
      expect(mapPortrait.size, 32);
      expect(find.byTooltip('내 탐험가 · H Hotel'), findsOneWidget);
      await _pump(
        tester,
        StageBriefingScreen(
          stage: _stages.first,
          playerCharacterId: 'CHAR_H',
          onBack: () {},
          onStart: () {},
          resume: false,
        ),
        size: const Size(680, 300),
        scale: 1.3,
      );
      final portrait = tester.widget<CompanionPortrait>(
        find.byKey(const ValueKey('briefing-player-portrait')),
      );
      expect(portrait.profile.id, 'CHAR_H');
      expect(find.text('H · Hotel'), findsOneWidget);
      expect(find.byType(GardenScene), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CompanionPortrait &&
              const {'CHAR_D', 'CHAR_J'}.contains(widget.profile.id),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('overall landmark map inspects fog without unlocking a stage', (
    tester,
  ) async {
    final selected = <String>[];
    await _pump(
      tester,
      _screen(onSelect: selected.add),
      size: const Size(680, 300),
      scale: 1.3,
    );
    await tester.tap(find.byKey(const ValueKey('expedition-overview')));
    await tester.pumpAndSettle();
    for (var chapter = 1; chapter <= 6; chapter++) {
      expect(
        find.byKey(ValueKey('expedition-destination-$chapter')),
        findsOneWidget,
      );
    }
    await tester.tap(find.byKey(const ValueKey('expedition-destination-6')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('expedition-stage-r01-c06-s01')),
    );
    expect(selected, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('milestone keeps save keys and cosmetics cannot unlock stages', (
    tester,
  ) async {
    final node = gardenDefinitions.first.restorationNodes.first;
    final choices = <String>[];
    var finishes = 0;
    await _pump(
      tester,
      ExpeditionMilestoneScreen(
        alreadyRestored: false,
        decorationId: 'wildflowers',
        onChooseDecoration: choices.add,
        onFinish: () => finishes++,
        node: node,
        restoredNodeIds: {node.id},
        completedStageCount: 2,
      ),
      size: const Size(680, 300),
      scale: 1.3,
    );
    final option = find.byKey(
      const ValueKey('expedition-decoration-stone-path'),
    );
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.tap(find.text('탐험을 계속하기'));
    expect(choices, ['stone-path']);
    expect(finishes, 1);
    expect(node.id, 'r01-c01-garden-02');
    expect(find.text(expeditionMilestoneTitle(node)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final capture in const ['entry', 'trail', 'overview', 'milestone']) {
    testWidgets('capture expedition $capture simulated landscape preview', (
      tester,
    ) async {
      final boundaryKey = GlobalKey();
      final completed = _stages.take(14).map((stage) => stage.id).toSet();
      final restored = gardenDefinitions.first.restorationNodes
          .where((node) => completed.contains(node.requiredStageId))
          .map((node) => node.id)
          .toSet();
      await _pump(
        tester,
        capture == 'milestone'
            ? ExpeditionMilestoneScreen(
                alreadyRestored: false,
                decorationId: 'stone-path',
                onChooseDecoration: (_) {},
                onFinish: () {},
                node: gardenDefinitions.first.restorationNodes[5],
                restoredNodeIds: restored,
                completedStageCount: 14,
              )
            : _screen(
                completed: capture == 'entry' ? {} : completed,
                unlocked: capture == 'entry'
                    ? {_stages.first.id}
                    : {...completed, 'r01-c02-s05'},
                restored: restored,
                nextStage: capture == 'entry' ? 'r01-c01-s01' : 'r01-c02-s05',
                canRestore: capture != 'entry',
              ),
        boundaryKey: boundaryKey,
      );
      if (capture == 'overview') {
        await tester.tap(find.byKey(const ValueKey('expedition-overview')));
        await tester.pumpAndSettle();
      }
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final pixels = await boundary.toImage(pixelRatio: 2);
        final bytes = await pixels.toByteData(format: ui.ImageByteFormat.png);
        expect(bytes, isNotNull);
        final directory = Directory('build/previews');
        await directory.create(recursive: true);
        await File(
          '${directory.path}/r1-expedition-$capture-800x360.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        pixels.dispose();
      });
    });
  }
}
