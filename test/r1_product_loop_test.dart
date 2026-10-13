import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/app/math_adventure_app.dart';
import 'package:kvm/core/theme/app_theme.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/campaign/data/r1_authored_campaign.dart';
import 'package:kvm/features/campaign/domain/campaign_models.dart';
import 'package:kvm/features/campaign/domain/learning_models.dart';
import 'package:kvm/features/discovery/data/discovery_runtime_catalog.dart';
import 'package:kvm/features/discovery/domain/discovery_models.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_screen.dart';
import 'package:kvm/features/discovery/presentation/engine_discovery_puzzle_view_model.dart';
import 'package:kvm/features/discovery/presentation/stage_session_controller.dart';
import 'package:kvm/features/garden/presentation/garden_screens.dart';
import 'package:kvm/features/garden/presentation/adventure_collection_screens.dart';
import 'package:kvm/features/garden/data/garden_catalog.dart';
import 'package:kvm/features/exploration/data/r1_expedition_catalog.dart';
import 'package:kvm/features/progress/progress.dart';

StageDefinition _stage(String id) => initialCampaign.stageById(id)!;

SaveEnvelopeV1 _existingPlayer(SaveEnvelopeV1 save) => save.copyWith(
  playerCharacterId: 'CHAR_D',
  onboardingCompleted: true,
  unlockedCharacterIds: {...save.unlockedCharacterIds, 'CHAR_D', 'CHAR_J'},
);

void _viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

StageSessionController _session(WidgetTester tester) =>
    tester
            .widget<DiscoveryPuzzleScreen>(find.byType(DiscoveryPuzzleScreen))
            .viewModel!
        as StageSessionController;

void _solve(EngineDiscoveryPuzzleViewModel model) {
  for (final swap in model.referencePath) {
    model.selectGem(swap.from.row * model.boardColumns + swap.from.column);
    model.selectGem(swap.to.row * model.boardColumns + swap.to.column);
  }
  for (final id in r1AnswerTokenIdsByStageId[model.stage.id]!) {
    if (!model.answerBlocks.any((block) => block.id == id)) {
      model.addBlockToAnswer(id);
    }
  }
  model.checkAnswer();
  expect(model.isAnswerCorrect, isTrue, reason: model.stage.id);
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String name,
) async {
  await tester.runAsync(() async {
    for (final widget in tester.widgetList<Image>(find.byType(Image))) {
      await precacheImage(widget.image, boundaryKey.currentContext!);
    }
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: name);
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final directory = Directory('build/previews');
    await directory.create(recursive: true);
    await File(
      '${directory.path}/r1_${name}_flutter-simulated.png',
    ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
  });
}

Future<void> _boot(
  WidgetTester tester,
  MemoryKeyValueSaveStore store,
  DateTime now, {
  GlobalKey? boundaryKey,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: MathAdventureApp(
        repository: ProgressRepository(
          store,
          initialFactory: () => _existingPlayer(SaveEnvelopeV1.initial()),
        ),
        assetBundle: rootBundle,
        now: () => now,
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(WorldMapScreen), findsOneWidget);
}

SaveEnvelopeV1 _reviewSeed({required bool due}) {
  final source = _stage('r01-c01-s06');
  final completed = initialCampaign.regions.first.chapters.first.stages
      .take(6)
      .map((stage) => stage.id)
      .toSet();
  // A deterministic developer fixture, not an observed family's learning data.
  // Calendar practice has no invented mastery evidence or delayed success.
  return SaveEnvelopeV1(
    completedStageIds: completed,
    unlockedStageIds: const ['r01-c01-s01', 'r01-c01-s07', 'r01-c04-s01'],
    stageLastPlayedDates: {for (final id in completed) id: '2026-10-11'},
    dailyActions: const {'2026-10-11': 6},
    skillProgress: {
      if (due)
        source.learningPlan.primarySkillId: SkillProgressSnapshot(
          skillId: source.learningPlan.primarySkillId,
          independentVariantProfiles: [source.learningPlan.variantProfile],
          pendingReviewTickets: [
            ReviewTicket(
              id: 'r1-ui-review-ticket',
              skillId: source.learningPlan.primarySkillId,
              sourceVariantId: source.id,
              sourceVariantProfile: source.learningPlan.variantProfile,
              policyIndex: 0,
              stageOffset: 2,
              dueAfterCompletedStageCount: 3,
              reason: ReviewReason.spacedPractice,
            ),
          ],
        ),
    },
  );
}

Future<MemoryKeyValueSaveStore> _seedStore(SaveEnvelopeV1 seed) async {
  final store = MemoryKeyValueSaveStore();
  await ProgressRepository(
    store,
    initialFactory: () => _existingPlayer(seed),
  ).update((save) => save.copyWith(viewedStoryIds: const ['fixture-ready']));
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = File(
      Platform.environment['KVM_PREVIEW_FONT'] ??
          r'C:\Windows\Fonts\malgun.ttf',
    );
    if (await font.exists()) {
      final data = ByteData.sublistView(await font.readAsBytes());
      for (final family in [
        'KvmPreviewKorean',
        'Roboto',
        'Segoe UI',
        'Malgun Gothic',
        'Noto Sans KR',
      ]) {
        final loader = FontLoader(family);
        loader.addFont(Future.value(data));
        await loader.load();
      }
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets(
    'R1 S01 → S02 → restoration → restart, with actual app captures',
    (tester) async {
      _viewport(tester, const Size(800, 360));
      final store = MemoryKeyValueSaveStore();
      final boundary = GlobalKey();
      await _boot(tester, store, DateTime(2026, 10, 11), boundaryKey: boundary);
      await _capture(tester, boundary, 'world-map_800x360_text100');
      await tester.tap(find.text('계산의 평원'));
      await tester.pumpAndSettle();
      expect(find.byType(CampaignRegionGardenScreen), findsOneWidget);
      await _capture(tester, boundary, 'garden-before_800x360_text100');
      await tester.tap(find.text('다음 탐험'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StageBriefingScreen>(find.byType(StageBriefingScreen))
            .stage!
            .id,
        'r01-c01-s01',
      );
      await tester.tap(find.text('탐험 시작하기'));
      await tester.pumpAndSettle();
      final first = _session(tester);
      await _capture(tester, boundary, 'puzzle-start_800x360_text100');
      _solve(first);
      await first.flush();
      await _capture(tester, boundary, 'puzzle-correct_800x360_text100');
      await tester.tap(find.text('결과 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(StageResultScreen), findsOneWidget);
      await _capture(tester, boundary, 'result_800x360_text100');
      await tester.tap(find.text('다음 탐험 안내'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StageBriefingScreen>(find.byType(StageBriefingScreen))
            .stage!
            .id,
        'r01-c01-s02',
      );
      await tester.tap(find.text('탐험 시작하기'));
      await tester.pumpAndSettle();
      final second = _session(tester);
      _solve(second);
      await second.flush();
      await tester.pumpAndSettle();
      await tester.tap(find.text('결과 보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('탐험의 흔적 남기기'));
      await tester.pumpAndSettle();
      expect(find.byType(RestorationRevealScreen), findsOneWidget);
      await _capture(tester, boundary, 'restoration_800x360_text100');
      await tester.tap(find.text(expeditionDecorationLabel('herbs')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('탐험을 계속하기'));
      await tester.pumpAndSettle();
      expect(find.byType(CampaignRegionGardenScreen), findsOneWidget);
      await _capture(tester, boundary, 'garden-after_800x360_text100');
      final saved = await ProgressRepository(store).load();
      expect(saved.completedStageIds, {'r01-c01-s01', 'r01-c01-s02'});
      expect(saved.restoredNodeIds, {'r01-c01-garden-02'});
      expect(saved.decorationChoices['r01-c01-garden-02'], 'herbs');
      expect(saved.rewardLedger, hasLength(2));
      expect(saved.activeSession, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _boot(tester, store, DateTime(2026, 10, 12));
      final restored = await ProgressRepository(store).load();
      expect(restored.bestStars, saved.bestStars);
      expect(restored.restoredNodeIds, saved.restoredNodeIds);
      expect(
        const DailyRouteService()
            .build(restored, initialCampaign, now: DateTime(2026, 10, 12))
            .explorationStage!
            .id,
        'r01-c01-s03',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final due in [false, true]) {
    testWidgets(
      '${due ? 'due' : 'calendar'} review resumes flags and continues core',
      (tester) async {
        _viewport(tester, const Size(800, 360));
        final store = await _seedStore(_reviewSeed(due: due));
        final boundary = GlobalKey();
        await _boot(
          tester,
          store,
          DateTime(2026, 10, 12),
          boundaryKey: boundary,
        );
        if (!due) {
          await _capture(
            tester,
            boundary,
            'review-card-nextday_800x360_text100',
          );
        }
        await tester.tap(find.text('기억의 씨앗'));
        await tester.pumpAndSettle();
        expect(find.byType(MemorySeedsScreen), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('memory-seed-play')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<StageBriefingScreen>(find.byType(StageBriefingScreen))
              .stage!
              .id,
          'r01-c04-s01',
        );
        await tester.tap(find.text('탐험 시작하기'));
        await tester.pumpAndSettle();
        var model = _session(tester);
        expect(model.isDailyReview, isTrue);
        expect(model.reviewTicketId, due ? 'r1-ui-review-ticket' : null);
        final firstSwap = model.referencePath.first;
        model.selectGem(
          firstSwap.from.row * model.boardColumns + firstSwap.from.column,
        );
        model.selectGem(
          firstSwap.to.row * model.boardColumns + firstSwap.to.column,
        );
        await model.flush();
        final checkpoint = (await ProgressRepository(
          store,
        ).load()).activeSession!;
        expect(checkpoint['isDailyReview'], true);
        expect(
          checkpoint['reviewTicketId'],
          due ? 'r1-ui-review-ticket' : null,
        );
        final attemptId = model.attemptId;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await _boot(tester, store, DateTime(2026, 10, 12));
        await tester.tap(find.text('오늘의 탐험'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('이어서 탐험하기'));
        await tester.pumpAndSettle();
        model = _session(tester);
        expect(model.attemptId, attemptId);
        expect(model.isDailyReview, isTrue);
        expect(model.reviewTicketId, due ? 'r1-ui-review-ticket' : null);
        final remainingPath = model.referencePath.skip(1);
        for (final swap in remainingPath) {
          model.selectGem(
            swap.from.row * model.boardColumns + swap.from.column,
          );
          model.selectGem(swap.to.row * model.boardColumns + swap.to.column);
        }
        for (final id in r1AnswerTokenIdsByStageId[model.stage.id]!) {
          model.addBlockToAnswer(id);
        }
        model.checkAnswer();
        expect(model.isAnswerCorrect, true);
        await model.flush();
        await tester.pumpAndSettle();
        await tester.tap(find.text('결과 보기'));
        await tester.pumpAndSettle();
        final saved = await ProgressRepository(store).load();
        expect(saved.dailyReviewActions['2026-10-12'], 1);
        expect(saved.completedStageIds, contains('r01-c04-s01'));
        final skill = saved
            .skillProgress[_stage('r01-c04-s01').learningPlan.primarySkillId]!;
        expect(skill.hasDelayedIndependentSuccess, false);
        expect(
          saved.masteryStates[skill.skillId],
          isNot(SkillMasteryState.mastered),
        );
        if (due) {
          expect(
            skill.pendingReviewTickets.single.id,
            isNot('r1-ui-review-ticket'),
          );
          expect(skill.pendingReviewTickets.single.stageOffset, 6);
        }
        await tester.tap(find.text('기억의 씨앗 확인하기'));
        await tester.pumpAndSettle();
        expect(find.byType(MemorySeedsScreen), findsOneWidget);
        await tester.tap(find.text('다음 탐험으로'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<StageBriefingScreen>(find.byType(StageBriefingScreen))
              .stage!
              .id,
          'r01-c01-s07',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('compact 130% actual R1 puzzle and result captures', (
    tester,
  ) async {
    _viewport(tester, const Size(680, 300));
    final seed = SaveEnvelopeV1(
      unlockedStageIds: const ['r01-c02-s05'],
      accessibility: AccessibilitySettings(textScale: 1.3),
    );
    final store = await _seedStore(seed);
    final boundary = GlobalKey();
    await _boot(tester, store, DateTime(2026, 10, 11), boundaryKey: boundary);
    await tester.tap(find.text('오늘의 탐험'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('탐험 시작하기'));
    await tester.pumpAndSettle();
    final model = _session(tester);
    _solve(model);
    await model.flush();
    await _capture(tester, boundary, 'puzzle_680x300_text130');
    await tester.tap(find.text('결과 보기'));
    await tester.pumpAndSettle();
    await _capture(tester, boundary, 'result_680x300_text130');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('all 60 R1 questions fully visible at 680x300 text $scale', (
      tester,
    ) async {
      _viewport(tester, const Size(680, 300));
      expect(
        initialCampaign.regions.first.stages.where((s) => s.isPlayable),
        hasLength(60),
      );
      for (final definition in initialCampaign.regions.first.stages.where(
        (stage) => stage.isPlayable,
      )) {
        final model = EngineDiscoveryPuzzleViewModel(
          stage: definition,
          boardConfig: DiscoveryBoardConfig.compactPhone,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: DiscoveryPuzzleScreen(viewModel: model),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: definition.id);
        final finder = find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText() == model.question,
        );
        expect(finder, findsOneWidget, reason: definition.id);
        final paragraph = tester.renderObject<RenderParagraph>(finder);
        expect(
          paragraph.didExceedMaxLines,
          false,
          reason: '${definition.id}: question must not have ellipsis',
        );
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: model.question.length),
        );
        expect(
          boxes.every((box) => box.bottom <= paragraph.size.height + 0.5),
          true,
          reason: '${definition.id}: question must not be vertically clipped',
        );
        _solve(model);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${definition.id}: complete answer layout',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
      }
    });
  }

  testWidgets('six restored garden projects and coming-soon captures', (
    tester,
  ) async {
    _viewport(tester, const Size(800, 360));
    final completed = initialCampaign.regions.first.stages
        .map((s) => s.id)
        .toSet();
    final nodes = gardenDefinitions.first.restorationNodes
        .map((n) => n.id)
        .toSet();
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: RepaintBoundary(
          key: boundary,
          child: CampaignRegionGardenScreen(
            stages: initialCampaign.regions.first.stages.toList(),
            completedStageIds: completed,
            unlockedStageIds: completed,
            restoredNodeIds: nodes,
            decorationChoices: {for (final id in nodes) id: 'herbs'},
            unlockedCharacterIds: const {
              'CHAR_D',
              'CHAR_J',
              'CHAR_L',
              'CHAR_U',
            },
            onBack: () {},
            onSelectStage: (_) {},
            onPlay: null,
            onRestore: () {},
            onStories: () {},
            hasActiveSession: false,
            canRestore: true,
          ),
        ),
      ),
    );
    for (final chapter in [1, 2, 3, 4, 5, 6]) {
      await tester.tap(find.byKey(ValueKey('expedition-chapter-$chapter')));
      await tester.pumpAndSettle();
      await _capture(
        tester,
        boundary,
        'complete-garden-c0${chapter}_800x360_text100',
      );
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: RepaintBoundary(
          key: boundary,
          child: RegionGardenScreen(
            regionId: 'region-03-unit',
            restoredNodeIds: const {},
            decorationChoices: const {},
            onBack: () {},
            onPlay: () {},
            onRestore: () {},
            canRestore: false,
            hasActiveSession: false,
            demoCompleted: false,
          ),
        ),
      ),
    );
    await _capture(tester, boundary, 'region-coming-soon_800x360_text100');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in const [
    Size(800, 360),
    Size(720, 320),
    Size(680, 300),
    Size(960, 432),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('advanced boards and seven-token answer $size / $scale', (
        tester,
      ) async {
        _viewport(tester, size);
        for (final id in [
          'r01-c03-s02',
          'r01-c05-s01',
          'r01-c05-s06',
          'r01-c06-s01',
        ]) {
          final model = EngineDiscoveryPuzzleViewModel(
            stage: _stage(id),
            boardConfig: size.height < 400
                ? DiscoveryBoardConfig.compactPhone
                : DiscoveryBoardConfig.standardPhone,
          );
          final boundary = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: RepaintBoundary(
                key: boundary,
                child: DiscoveryPuzzleScreen(viewModel: model),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final capture =
              (size == const Size(800, 360) && scale == 1.0) ||
              (size == const Size(680, 300) && scale == 1.3);
          final prefix =
              '${id}_${size.width.toInt()}x${size.height.toInt()}_text${(scale * 100).round()}';
          if (capture)
            await _capture(tester, boundary, 'advanced-start_$prefix');
          var capturedPower = false;
          for (final swap in model.referencePath) {
            model.selectGem(
              swap.from.row * model.boardColumns + swap.from.column,
            );
            model.selectGem(swap.to.row * model.boardColumns + swap.to.column);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$prefix / swap');
            if (capture &&
                !capturedPower &&
                model.boardCells.any((c) => c.linePowerKind != null)) {
              capturedPower = true;
              await _capture(tester, boundary, 'advanced-power_$prefix');
            }
          }
          for (final tokenId in r1AnswerTokenIdsByStageId[id]!)
            model.addBlockToAnswer(tokenId);
          model.checkAnswer();
          expect(model.isAnswerCorrect, true, reason: prefix);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$prefix / correct');
          if (capture)
            await _capture(tester, boundary, 'advanced-correct_$prefix');
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
        }
      });
    }
  }

  for (final size in const [
    Size(800, 360),
    Size(720, 320),
    Size(680, 300),
    Size(960, 432),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'R1 ${size.width.toInt()}x${size.height.toInt()} text $scale screen matrix',
        (tester) async {
          _viewport(tester, size);
          final definition = _stage('r01-c02-s05');
          final puzzle = discoveryRuntimeCatalog.resolve(definition).puzzle;
          final model = EngineDiscoveryPuzzleViewModel(
            stage: definition,
            boardConfig: size.height < 400
                ? DiscoveryBoardConfig.compactPhone
                : DiscoveryBoardConfig.standardPhone,
          );
          addTearDown(model.dispose);
          final screens = <Widget>[
            CampaignRegionGardenScreen(
              stages: initialCampaign.regions.first.stages
                  .where((s) => s.isPlayable)
                  .toList(),
              completedStageIds: const {'r01-c01-s01', 'r01-c01-s02'},
              unlockedStageIds: const {
                'r01-c01-s01',
                'r01-c01-s02',
                'r01-c01-s03',
              },
              restoredNodeIds: const {'r01-c01-garden-02'},
              decorationChoices: const {'r01-c01-garden-02': 'herbs'},
              onBack: () {},
              onSelectStage: (_) {},
              onPlay: () {},
              onRestore: () {},
              onStories: () {},
              hasActiveSession: false,
              canRestore: true,
            ),
            StageBriefingScreen(
              stage: definition,
              onBack: () {},
              onStart: () {},
              resume: false,
            ),
            DiscoveryPuzzleScreen(viewModel: model),
            StageResultScreen(
              stage: definition,
              puzzle: puzzle,
              stars: 3,
              firstCompletion: true,
              onContinue: () {},
              onBack: () {},
              continueLabel: '다음 탐험 안내',
            ),
            RestorationRevealScreen(
              nodeTitle: '새싹 깨우기',
              restoredNodeIds: const {'r01-c01-garden-02'},
              completedStageCount: 2,
              alreadyRestored: false,
              decorationId: 'herbs',
              onChooseDecoration: (_) {},
              onFinish: () {},
            ),
          ];
          for (final screen in screens) {
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: screen,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${screen.runtimeType}: $size / $scale',
            );
            if (screen is DiscoveryPuzzleScreen) {
              _solve(model);
              model.revealHint();
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
