import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/app/math_adventure_app.dart';
import 'package:kvm/core/theme/app_theme.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/discovery/data/tutorial_discovery_fixture.dart';
import 'package:kvm/features/discovery/domain/discovery_models.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_screen.dart';
import 'package:kvm/features/discovery/presentation/engine_discovery_puzzle_view_model.dart';
import 'package:kvm/features/discovery/presentation/stage_session_controller.dart';
import 'package:kvm/features/garden/presentation/garden_screens.dart';
import 'package:kvm/features/progress/progress.dart';

class _ControlledStore extends MemoryKeyValueSaveStore {
  bool failNextPointer = false;
  bool holdNextPointer = false;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> write(String key, String value) async {
    if (key == ProgressRepository.pointerKey) {
      if (failNextPointer) {
        failNextPointer = false;
        throw const SaveWriteException('Transient pointer write failure.');
      }
      if (holdNextPointer) {
        holdNextPointer = false;
        entered.complete();
        await release.future;
      }
    }
    await super.write(key, value);
  }
}

void solveModel(StageSessionController model) {
  for (final step in DiscoveryTutorialFixture.steps) {
    model.selectGem(step.from.row * model.boardColumns + step.from.column);
    model.selectGem(step.to.row * model.boardColumns + step.to.column);
  }
  for (final id in ['p1-n4', 'p1-times', 'p1-n3', 'p1-plus', 'p1-n2']) {
    model.addBlockToAnswer(id);
  }
  model.checkAnswer();
}

Future<void> configureViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget previewHost(Widget screen, {double scale = 1}) => MaterialApp(
  theme: AppTheme.light(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: screen,
);

Future<StageSessionController> enterPuzzle(WidgetTester tester) async {
  await tester.tap(find.text('계산의 평원'));
  await tester.pumpAndSettle();
  expect(find.byType(RegionGardenScreen), findsOneWidget);
  await tester.tap(find.text('체험 탐험하기'));
  await tester.pumpAndSettle();
  expect(find.byType(StageBriefingScreen), findsOneWidget);
  await tester.tap(find.text('탐험 시작하기'));
  await tester.pumpAndSettle();
  return tester
          .widget<DiscoveryPuzzleScreen>(find.byType(DiscoveryPuzzleScreen))
          .viewModel!
      as StageSessionController;
}

Future<void> tapDiscoveryStep(
  WidgetTester tester,
  StageSessionController model,
  int index,
) async {
  final step = DiscoveryTutorialFixture.steps[index];
  for (final position in [step.from, step.to]) {
    final gems = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(InkWell),
    );
    await tester.tap(
      gems.at(position.row * model.boardColumns + position.column),
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'herb selection queued before finish is preserved by delayed storage',
    (tester) async {
      await configureViewport(tester, const Size(800, 360));
      final store = _ControlledStore();
      final repository = ProgressRepository(store);
      final model = StageSessionController(
        repository: repository,
        stage: verticalSliceStage,
        boardConfig: DiscoveryBoardConfig.compactPhone,
        onContinue: () {},
        onSaveError: (e) => fail('$e'),
      );
      solveModel(model);
      model.pauseSaving();
      await model.flush();
      await StageCompletionService(repository).complete(model.result());
      model.dispose();
      await tester.pumpWidget(
        MathAdventureApp(
          repository: repository,
          campaign: prototypeCampaign,
          assetBundle: rootBundle,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('정원 돌보기'));
      await tester.pumpAndSettle();
      expect(find.byType(RestorationRevealScreen), findsOneWidget);
      store.holdNextPointer = true;
      await tester.tap(find.text('향기로운 허브'));
      await tester.pump();
      expect(store.entered.isCompleted, isTrue);
      await tester.tap(find.text('이 모습으로 복원하기'));
      await tester.pump();
      store.release.complete();
      await tester.pumpAndSettle();
      expect(find.byType(RegionGardenScreen), findsOneWidget);
      final save = await ProgressRepository(store).load();
      expect(save.decorationChoices['r01-demo-meadow'], 'herbs');
      expect(save.viewedStoryIds, contains('r01-demo-story'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'result action can retry a transient checkpoint failure without duplicate reward',
    (tester) async {
      await configureViewport(tester, const Size(800, 360));
      final store = _ControlledStore();
      await tester.pumpWidget(
        MathAdventureApp(
          repository: ProgressRepository(store),
          campaign: prototypeCampaign,
          assetBundle: rootBundle,
        ),
      );
      await tester.pumpAndSettle();
      final model = await enterPuzzle(tester);
      solveModel(model);
      await model.flush();
      await tester.pumpAndSettle();
      store.failNextPointer = true;
      await tester.tap(find.text('결과 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(DiscoveryPuzzleScreen), findsOneWidget);
      expect(find.byType(StageResultScreen), findsNothing);
      expect((await ProgressRepository(store).load()).rewardLedger, isEmpty);
      await tester.tap(find.text('결과 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(StageResultScreen), findsOneWidget);
      final recovered = await ProgressRepository(store).load();
      expect(recovered.rewardLedger.length, 1);
      expect(recovered.activeSession, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'world map → puzzle → reward → restoration survives app restart',
    (tester) async {
      await configureViewport(tester, const Size(800, 360));
      final store = MemoryKeyValueSaveStore();
      await tester.pumpWidget(
        MathAdventureApp(
          repository: ProgressRepository(store),
          campaign: prototypeCampaign,
          assetBundle: rootBundle,
        ),
      );
      await tester.pumpAndSettle();
      final model = await enterPuzzle(tester);
      for (var i = 0; i < 3; i++) {
        await tapDiscoveryStep(tester, model, i);
      }
      expect(model.discoveredBlocks.length, 5);
      for (final label in ['4', '×', '3', '+', '2']) {
        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == '$label 블록, 식에 추가',
          ),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(model.isAnswerCorrect, isTrue);
      await tester.tap(find.text('결과 보기'));
      await tester.pumpAndSettle();
      expect(find.byType(StageResultScreen), findsOneWidget);
      final firstSave = await ProgressRepository(store).load();
      expect(firstSave.completedStageIds, {verticalSliceStage.id});
      expect(firstSave.rewardLedger.length, 1);
      expect(firstSave.activeSession, isNull);
      expect(
        firstSave.unlockedStageIds,
        SaveEnvelopeV1.initial().unlockedStageIds,
      );
      expect(
        initialCampaign.stages.where((stage) => stage.isPlayable).length,
        60,
      );
      await tester.tap(find.text('첫 화단 복원하기'));
      await tester.pumpAndSettle();
      expect(find.byType(RestorationRevealScreen), findsOneWidget);
      await tester.tap(find.text('이 모습으로 복원하기'));
      await tester.pumpAndSettle();
      expect(find.byType(RegionGardenScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MathAdventureApp(
          repository: ProgressRepository(store),
          campaign: prototypeCampaign,
          assetBundle: rootBundle,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WorldMapScreen), findsOneWidget);
      await tester.tap(find.text('계산의 평원'));
      await tester.pumpAndSettle();
      expect(find.text('정원 장식 바꾸기'), findsOneWidget);
      final restarted = await ProgressRepository(store).load();
      expect(restarted.restoredNodeIds, {'r01-demo-meadow'});
      expect(restarted.viewedStoryIds, contains('r01-demo-story'));
      expect(restarted.bestStars, firstSave.bestStars);
      expect(restarted.rewardLedger.length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'closing and reopening restores mid-board and unfinished equation',
    (tester) async {
      await configureViewport(tester, const Size(800, 360));
      final store = MemoryKeyValueSaveStore();
      await tester.pumpWidget(
        MathAdventureApp(
          repository: ProgressRepository(store),
          campaign: prototypeCampaign,
          assetBundle: rootBundle,
        ),
      );
      await tester.pumpAndSettle();
      final model = await enterPuzzle(tester);
      await tapDiscoveryStep(tester, model, 0);
      model.addBlockToAnswer('p1-n4');
      await model.flush();
      final snapshot = model.exportSession();
      final attemptId = model.attemptId;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MathAdventureApp(
          repository: ProgressRepository(store),
          campaign: prototypeCampaign,
          assetBundle: rootBundle,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('계산의 평원'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이어서 탐험하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이어서 탐험하기'));
      await tester.pumpAndSettle();
      final restored =
          tester
                  .widget<DiscoveryPuzzleScreen>(
                    find.byType(DiscoveryPuzzleScreen),
                  )
                  .viewModel!
              as StageSessionController;
      expect(restored.attemptId, attemptId);
      expect(restored.exportSession(), snapshot);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final size in const [
    Size(800, 360),
    Size(720, 320),
    Size(680, 300),
    Size(960, 432),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        '${size.width.toInt()}x${size.height.toInt()} text $scale: all loop screens fit',
        (tester) async {
          await configureViewport(tester, size);
          final model = EngineDiscoveryPuzzleViewModel(
            boardConfig: size.width < 720 || size.height < 400
                ? DiscoveryBoardConfig.compactPhone
                : DiscoveryBoardConfig.standardPhone,
          );
          addTearDown(model.dispose);
          final screens = <Widget>[
            WorldMapScreen(
              unlockedRegionIds: const {'region-01-calculation'},
              restoredNodeIds: const {},
              totalStars: 0,
              weeklyActions: 0,
              onExplore: () {},
              onSelectRegion: (_) {},
              onSettings: () {},
            ),
            RegionGardenScreen(
              regionId: 'region-01-calculation',
              restoredNodeIds: const {},
              decorationChoices: const {},
              onBack: () {},
              onPlay: () {},
              onRestore: () {},
              canRestore: false,
              hasActiveSession: false,
              demoCompleted: false,
            ),
            StageBriefingScreen(onBack: () {}, onStart: () {}, resume: false),
            DiscoveryPuzzleScreen(viewModel: model),
            StageResultScreen(
              stars: 2,
              firstCompletion: true,
              onContinue: () {},
              onBack: () {},
            ),
            RestorationRevealScreen(
              alreadyRestored: false,
              decorationId: 'wildflowers',
              onChooseDecoration: (_) {},
              onFinish: () {},
            ),
            RegionGardenScreen(
              regionId: 'region-01-calculation',
              restoredNodeIds: const {'r01-demo-meadow'},
              decorationChoices: const {'r01-demo-meadow': 'herbs'},
              onBack: () {},
              onPlay: () {},
              onRestore: () {},
              canRestore: true,
              hasActiveSession: false,
              demoCompleted: true,
            ),
          ];
          for (final screen in screens) {
            await tester.pumpWidget(previewHost(screen, scale: scale));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${screen.runtimeType} at $size text $scale',
            );
            if (screen is DiscoveryPuzzleScreen) {
              for (final step in DiscoveryTutorialFixture.steps) {
                model.selectGem(
                  step.from.row * model.boardColumns + step.from.column,
                );
                model.selectGem(
                  step.to.row * model.boardColumns + step.to.column,
                );
              }
              model.revealHint();
              model.revealHint();
              await tester.pumpAndSettle();
              final paragraph = tester.renderObject<RenderParagraph>(
                find.text(model.feedbackMessage),
              );
              final boxes = paragraph.getBoxesForSelection(
                TextSelection(
                  baseOffset: 0,
                  extentOffset: model.feedbackMessage.length,
                ),
              );
              expect(
                boxes.every((box) => box.bottom <= paragraph.size.height + 0.5),
                isTrue,
                reason:
                    'Hint text must not be physically clipped at $size text $scale',
              );
              await tester.tap(find.text(model.feedbackMessage));
              await tester.pumpAndSettle();
              expect(
                find.descendant(
                  of: find.byType(AlertDialog),
                  matching: find.text(model.feedbackMessage),
                ),
                findsOneWidget,
              );
              await tester.tap(find.text('닫기'));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              model.resetRound();
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
