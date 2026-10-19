import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/app/math_adventure_app.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/discovery/data/authored_discovery_fixture.dart';
import 'package:kvm/features/discovery/data/discovery_runtime_catalog.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_screen.dart';
import 'package:kvm/features/discovery/presentation/stage_session_controller.dart';
import 'package:kvm/features/exploration/presentation/r1_expedition_screen.dart';
import 'package:kvm/features/exploration/presentation/pattern_forest_backdrop.dart';
import 'package:kvm/features/garden/presentation/garden_screens.dart';
import 'package:kvm/features/progress/progress.dart';

void _viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _boot(WidgetTester tester, MemoryKeyValueSaveStore store) async {
  await tester.pumpWidget(
    MathAdventureApp(
      repository: ProgressRepository(store),
      assetBundle: rootBundle,
      now: () => DateTime(2026, 10, 13),
    ),
  );
  await tester.pumpAndSettle();
}

StageSessionController _session(WidgetTester tester) =>
    tester
            .widget<DiscoveryPuzzleScreen>(find.byType(DiscoveryPuzzleScreen))
            .viewModel!
        as StageSessionController;

void _swap(StageSessionController model, DiscoverySwapInstruction step) {
  model.selectGem(step.from.row * model.boardColumns + step.from.column);
  model.selectGem(step.to.row * model.boardColumns + step.to.column);
}

void main() {
  testWidgets(
    'R1 gate clear -> R2 real puzzle -> restart -> trace -> next stage',
    (tester) async {
      _viewport(tester, const Size(800, 360));
      final store = MemoryKeyValueSaveStore();
      final completed =
          initialCampaign.regions.first.chapters
              .take(3)
              .expand((c) => c.stages)
              .map((s) => s.id)
              .toSet()
            ..remove('r01-c03-s10');
      // Preparation is an imported save. The R2 attempts below use real swaps and
      // expression submission, not completion-service stubs.
      await ProgressRepository(
        store,
        initialFactory: () => SaveEnvelopeV1(
          completedStageIds: completed,
          unlockedStageIds: const {'r01-c01-s01'},
          playerCharacterId: 'CHAR_D',
          onboardingCompleted: true,
          viewedStoryIds: const {
            'expedition-join-CHAR_J',
            'expedition-join-CHAR_L',
          },
        ),
      ).update((save) => save.copyWith(dailyActions: const {'2026-10-12': 1}));
      await _boot(tester, store);
      final world = tester.widget<WorldMapScreen>(find.byType(WorldMapScreen));
      expect(world.availableRegionIds, contains('region-02-pattern'));
      expect(world.unlockedRegionIds, isNot(contains('region-02-pattern')));
      expect(world.availableRegionIds, isNot(contains('region-03-unit')));
      await tester.tap(find.byKey(const ValueKey('world-explore')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StageBriefingScreen>(find.byType(StageBriefingScreen))
            .stage!
            .id,
        'r01-c03-s10',
      );
      await tester.tap(find.text('탐험 시작하기'));
      await tester.pumpAndSettle();
      final gateSession = _session(tester);
      final gateRuntime = discoveryRuntimeCatalog.resolve(gateSession.stage);
      for (final step in gateSession.referencePath) _swap(gateSession, step);
      for (final token in gateRuntime.puzzle.tokens)
        gateSession.addBlockToAnswer(token.id);
      gateSession.checkAnswer();
      expect(gateSession.isAnswerCorrect, isTrue);
      await gateSession.flush();
      await tester.pumpAndSettle();
      await tester.tap(find.text('결과 보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('탐험의 흔적 남기기'));
      await tester.pumpAndSettle();
      tester
          .widget<RestorationRevealScreen>(find.byType(RestorationRevealScreen))
          .onFinish();
      await tester.pumpAndSettle();
      tester
          .widget<CampaignRegionGardenScreen>(
            find.byType(CampaignRegionGardenScreen),
          )
          .onBack();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WorldMapScreen>(find.byType(WorldMapScreen))
            .unlockedRegionIds,
        contains('region-02-pattern'),
      );
      await tester.tap(find.byKey(const ValueKey('world-explore')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StageBriefingScreen>(find.byType(StageBriefingScreen))
            .stage!
            .id,
        'r02-c01-s01',
      );
      await tester.tap(find.text('탐험 시작하기'));
      await tester.pumpAndSettle();
      final original = _session(tester);
      final runtime = discoveryRuntimeCatalog.resolve(original.stage);
      final path = original.referencePath;
      _swap(original, path.first);
      original.addBlockToAnswer(runtime.puzzle.tokens.first.id);
      await original.checkpoint();
      final checkpoint = original.exportSession();
      final attempt = original.attemptId;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _boot(tester, store);
      await tester.tap(find.byKey(const ValueKey('world-explore')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이어서 탐험하기').last);
      await tester.pumpAndSettle();
      final resumed = _session(tester);
      expect(resumed.attemptId, attempt);
      expect(resumed.exportSession(), checkpoint);
      for (final step in path.skip(1)) _swap(resumed, step);
      // Finish using the authored token instances (including repeated values).
      for (final block in resumed.answerBlocks.toList())
        resumed.removeBlockFromAnswer(block.id);
      for (final token in runtime.puzzle.tokens)
        resumed.addBlockToAnswer(token.id);
      resumed.checkAnswer();
      expect(resumed.isAnswerCorrect, isTrue);
      await resumed.flush();
      await tester.pumpAndSettle();
      await tester.tap(find.text('결과 보기'));
      await tester.pumpAndSettle();
      final result = tester.widget<StageResultScreen>(
        find.byType(StageResultScreen),
      );
      result.onContinue();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StageBriefingScreen>(find.byType(StageBriefingScreen))
            .stage!
            .id,
        'r02-c01-s02',
      );
      await tester.tap(find.text('탐험 시작하기'));
      await tester.pumpAndSettle();
      final second = _session(tester);
      final secondRuntime = discoveryRuntimeCatalog.resolve(second.stage);
      for (final step in second.referencePath) _swap(second, step);
      for (final token in secondRuntime.puzzle.tokens)
        second.addBlockToAnswer(token.id);
      second.checkAnswer();
      expect(second.isAnswerCorrect, isTrue);
      await second.flush();
      await tester.pumpAndSettle();
      await tester.tap(find.text('결과 보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('탐험의 흔적 남기기'));
      await tester.pumpAndSettle();
      final trace = tester.widget<RestorationRevealScreen>(
        find.byType(RestorationRevealScreen),
      );
      expect(trace.node!.regionId, 'region-02-pattern');
      trace.onFinish();
      await tester.pumpAndSettle();
      expect(find.byType(PatternForestBackdrop), findsWidgets);
      final save = await ProgressRepository(store).load();
      expect(save.restoredNodeIds, contains('r02-c01-garden-02'));
      expect(
        save.completedStageIds,
        containsAll([
          ...completed,
          'r01-c03-s10',
          'r02-c01-s01',
          'r02-c01-s02',
        ]),
      );
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
    for (final scale in const [1.0, 1.3]) {
      testWidgets('R2 map fits $size at $scale', (tester) async {
        _viewport(tester, size);
        final stages = initialCampaign.regions[1].stages.toList();
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: R1ExpeditionScreen(
                regionNumber: 2,
                stages: stages,
                completedStageIds: const {},
                unlockedStageIds: const {'r02-c01-s01'},
                restoredNodeIds: const {},
                decorationChoices: const {},
                onBack: () {},
                onSelectStage: (_) {},
                onPlay: () {},
                onRestore: () {},
                hasActiveSession: false,
                canRestore: false,
                nextStageId: 'r02-c01-s01',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('규칙과 패턴의 숲 · 탐험 지도'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('expedition-stage-r02-c01-s10')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
