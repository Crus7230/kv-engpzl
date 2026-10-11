import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/app/math_adventure_app.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/campaign/data/r1_authored_campaign.dart';
import 'package:kvm/features/discovery/data/discovery_runtime_catalog.dart';
import 'package:kvm/features/discovery/domain/discovery_models.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_screen.dart';
import 'package:kvm/features/discovery/presentation/stage_session_controller.dart';
import 'package:kvm/features/garden/data/garden_catalog.dart';
import 'package:kvm/features/garden/domain/garden_models.dart';
import 'package:kvm/features/garden/presentation/garden_screens.dart';
import 'package:kvm/features/progress/progress.dart';

void _viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 360);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _boot(
  WidgetTester tester,
  MemoryKeyValueSaveStore store,
  DateTime now,
) async {
  await tester.pumpWidget(
    MathAdventureApp(
      repository: ProgressRepository(store),
      assetBundle: rootBundle,
      now: () => now,
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(WorldMapScreen), findsOneWidget);
  expect(tester.takeException(), isNull);
}

Future<void> _tap(WidgetTester tester, Finder finder, String step) async {
  expect(finder, findsOneWidget, reason: step);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: step);
}

StageSessionController _session(WidgetTester tester) =>
    tester
            .widget<DiscoveryPuzzleScreen>(find.byType(DiscoveryPuzzleScreen))
            .viewModel!
        as StageSessionController;

Future<void> _solve(WidgetTester tester, StageSessionController model) async {
  final variant = model.stage.boardVariants.variantFor(
    DiscoveryBoardConfig(rows: model.boardRows, columns: model.boardColumns),
  );
  final runtime = discoveryRuntimeCatalog.resolve(model.stage);
  // Real runtime swaps and answer submissions drive the app's session/save
  // controller. This is not a pre-completed save or a completion-service stub.
  for (final swap in runtime.referencePathFor!(variant)) {
    model.selectGem(swap.from.row * model.boardColumns + swap.from.column);
    model.selectGem(swap.to.row * model.boardColumns + swap.to.column);
  }
  for (final id in r1AnswerTokenIdsByStageId[model.stage.id]!) {
    model.addBlockToAnswer(id);
  }
  model.checkAnswer();
  expect(model.isAnswerCorrect, isTrue, reason: model.stage.id);
  await model.flush();
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: model.stage.id);
}

Future<void> _restore(
  WidgetTester tester,
  RestorationNode node,
  String decoration,
) async {
  final screen = tester.widget<RestorationRevealScreen>(
    find.byType(RestorationRevealScreen),
  );
  expect(screen.node!.id, node.id);
  expect(find.text(node.storyText!), findsOneWidget);
  await _tap(tester, find.text(gardenDecorationLabel(decoration)), node.id);
  await _tap(tester, find.text('이 모습으로 꾸미기'), '${node.id} finish restoration');
  expect(find.byType(CampaignRegionGardenScreen), findsOneWidget);
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
    'actual app completes all 60 R1 stages and 24 restorations without a dead end',
    (tester) async {
      _viewport(tester);
      final store = MemoryKeyValueSaveStore();
      final region = initialCampaign.regions.first;
      final stages = region.stages.toList();
      final garden = gardenDefinitions.first;
      await _boot(tester, store, DateTime(2026, 10, 11));
      await _tap(tester, find.text('오늘의 탐험'), 'first daily exploration');
      final restored = <String>{};

      for (var index = 0; index < stages.length; index++) {
        final stage = stages[index];
        final briefing = tester.widget<StageBriefingScreen>(
          find.byType(StageBriefingScreen),
        );
        expect(briefing.stage!.id, stage.id);
        await _tap(tester, find.text('탐험 시작하기'), '${stage.id} start');
        final model = _session(tester);
        expect(model.stage.id, stage.id);
        await _solve(tester, model);
        await _tap(tester, find.text('결과 보기'), '${stage.id} result');
        expect(find.byType(StageResultScreen), findsOneWidget);
        final saved = await ProgressRepository(store).load();
        expect(saved.completedStageIds, hasLength(index + 1));
        expect(saved.rewardLedger, hasLength(index + 1));
        expect(saved.bestStars[stage.id], greaterThanOrEqualTo(1));
        expect(saved.activeSession, isNull);

        if (const [2, 4, 7, 10].contains(stage.number)) {
          final node = garden.restorationNodes.singleWhere(
            (node) => node.requiredStageId == stage.id,
          );
          await _tap(
            tester,
            find.text('열린 정원 복원하기'),
            '${stage.id} restoration reward',
          );
          await _restore(tester, node, gardenDecorationIds[index % 3]);
          restored.add(node.id);
          final afterRestoration = await ProgressRepository(store).load();
          expect(afterRestoration.restoredNodeIds, restored);
          expect(afterRestoration.viewedStoryIds, contains(node.storyId));
          expect(
            afterRestoration.decorationChoices[node.id],
            gardenDecorationIds[index % 3],
          );
          if (index + 1 < stages.length) {
            await _tap(tester, find.text('다음 탐험'), '${stage.id} next garden');
          }
        } else {
          await _tap(
            tester,
            find.text('다음 탐험 안내'),
            '${stage.id} next briefing',
          );
        }
      }

      final complete = await ProgressRepository(store).load();
      expect(complete.completedStageIds, hasLength(60));
      expect(complete.restoredNodeIds, hasLength(24));
      expect(complete.rewardLedger, hasLength(60));
      expect(
        complete.unlockedCharacterIds,
        region.featuredCharacterIds.toSet(),
      );
      expect(complete.unlockedStageIds, contains('r02-c01-s01'));
      expect(find.text('계산의 평원 완료 · 다음 지역 업데이트 예정'), findsOneWidget);
      final completeGarden = tester.widget<CampaignRegionGardenScreen>(
        find.byType(CampaignRegionGardenScreen),
      );
      expect(completeGarden.onPlay, isNull);
      expect(find.text('탐험 묶음 완료'), findsOneWidget);

      // Every project tab selects its own composited scene and chapter path.
      final labels = ['C01', 'C02', 'C03', '기억', '공방', '심화'];
      for (var chapter = 0; chapter < labels.length; chapter++) {
        await _tap(
          tester,
          find.text(labels[chapter]),
          'project ${labels[chapter]}',
        );
        final scene = tester.widget<GardenScene>(find.byType(GardenScene));
        expect(scene.project!.chapterId, 'r01-c0${chapter + 1}');
      }

      // Read every unlocked character story. Merely unlocking a character did
      // not mark these stories viewed during the campaign completion loop.
      for (final story in r1CharacterStories) {
        expect(complete.viewedStoryIds, isNot(contains(story.id)));
        await _tap(tester, find.text('친구들의 이야기'), '${story.id} chooser');
        final storyEntry = find.text(
          '${story.characterId.substring(5)} · ${story.title}',
        );
        // Modal lists build only their visible entries. Scroll before looking
        // up L/U; ensureVisible alone cannot locate an unbuilt list child.
        await tester.scrollUntilVisible(
          storyEntry,
          60,
          scrollable: find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await _tap(tester, storyEntry, '${story.id} open');
        expect(find.text(story.text), findsOneWidget);
        await _tap(tester, find.text('닫기'), '${story.id} read');
        expect(
          (await ProgressRepository(store).load()).viewedStoryIds,
          contains(story.id),
        );
      }

      // One selected node changes for free; all other choices, stars, and
      // completion receipts remain untouched.
      final beforeDecoration = await ProgressRepository(store).load();
      final firstNode = garden.restorationNodes.first;
      await _tap(tester, find.text('정원 돌보기'), 'per-node decoration chooser');
      expect(find.text('돌볼 정원을 고르세요'), findsOneWidget);
      await _tap(
        tester,
        find.text(firstNode.title),
        'choose first restored node',
      );
      await _restore(tester, firstNode, 'herbs');
      final afterDecoration = await ProgressRepository(store).load();
      expect(afterDecoration.decorationChoices[firstNode.id], 'herbs');
      expect(afterDecoration.bestStars, beforeDecoration.bestStars);
      expect(
        afterDecoration.rewardLedger.length,
        beforeDecoration.rewardLedger.length,
      );
      expect(
        afterDecoration.completedStageIds,
        beforeDecoration.completedStageIds,
      );
      for (final entry in beforeDecoration.decorationChoices.entries) {
        if (entry.key != firstNode.id) {
          expect(afterDecoration.decorationChoices[entry.key], entry.value);
        }
      }

      // R2's stable unlock metadata is present, but no planned region has an
      // executable puzzle or exploration button in this release.
      await _tap(tester, find.byTooltip('이전 화면'), 'garden back to world');
      await _tap(
        tester,
        find.byTooltip('규칙과 패턴의 숲 · 업데이트 예정'),
        'R2 update placeholder',
      );
      expect(find.text('업데이트 예정'), findsWidgets);
      expect(find.byType(DiscoveryPuzzleScreen), findsNothing);
      expect(find.byType(StageBriefingScreen), findsNothing);
      expect(find.text('체험 탐험하기'), findsNothing);
      await _tap(tester, find.text('월드맵으로'), 'return from R2');
      expect(
        tester.widget<WorldMapScreen>(find.byType(WorldMapScreen)).onExplore,
        isNull,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _boot(tester, store, DateTime(2026, 10, 12));
      final resumed = await ProgressRepository(store).load();
      expect(resumed.completedStageIds, afterDecoration.completedStageIds);
      expect(resumed.restoredNodeIds, afterDecoration.restoredNodeIds);
      expect(resumed.decorationChoices, afterDecoration.decorationChoices);
      expect(resumed.viewedStoryIds, afterDecoration.viewedStoryIds);
      expect(find.text('평원 완료 · 다음 지역 업데이트 예정'), findsOneWidget);
      final world = tester.widget<WorldMapScreen>(find.byType(WorldMapScreen));
      expect(world.onExplore, isNull);
      expect(world.onReview, isNotNull);

      // The next day's review is a real replay, not a falsely advertised new
      // stage. It must complete without duplicating garden restoration rewards.
      await _tap(tester, find.text('기억의 씨앗'), 'next-day review');
      await _tap(tester, find.text('탐험 시작하기'), 'review start');
      final review = _session(tester);
      expect(review.isDailyReview, isTrue);
      expect(resumed.completedStageIds, contains(review.stage.id));
      await _solve(tester, review);
      await _tap(tester, find.text('결과 보기'), 'review result');
      final reviewResult = tester.widget<StageResultScreen>(
        find.byType(StageResultScreen),
      );
      expect(reviewResult.firstCompletion, isFalse);
      expect(reviewResult.hasRestoration, isFalse);
      final afterReview = await ProgressRepository(store).load();
      expect(afterReview.completedStageIds, hasLength(60));
      expect(afterReview.restoredNodeIds, hasLength(24));
      expect(afterReview.rewardLedger, hasLength(61));
      expect(afterReview.dailyReviewActions['2026-10-12'], 1);
      await _tap(tester, find.text('정원으로 돌아가기'), 'review natural endpoint');
      expect(find.byType(CampaignRegionGardenScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    'a persisted future-region unlock never opens planned R2 gameplay',
    (tester) async {
      _viewport(tester);
      final store = MemoryKeyValueSaveStore();
      await ProgressRepository(
        store,
        initialFactory: () => SaveEnvelopeV1(
          unlockedStageIds: const ['r02-c01-s01'],
          completedStageIds: const ['r01-c03-s10'],
        ),
      ).update(
        (save) => save.copyWith(viewedStoryIds: const ['fixture-ready']),
      );
      await _boot(tester, store, DateTime(2026, 10, 11));
      final world = tester.widget<WorldMapScreen>(find.byType(WorldMapScreen));
      expect(world.onExplore, isNull);
      expect(world.availableRegionIds, isNot(contains('region-02-pattern')));
      await _tap(
        tester,
        find.byTooltip('규칙과 패턴의 숲 · 업데이트 예정'),
        'forced unlocked R2',
      );
      expect(find.text('업데이트 예정'), findsWidgets);
      expect(find.byType(DiscoveryPuzzleScreen), findsNothing);
      expect(find.byType(StageBriefingScreen), findsNothing);
      expect(find.text('탐험 시작하기'), findsNothing);
      expect((await ProgressRepository(store).load()).rewardLedger, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('C05/C06 imported unlocks remain disabled in chapter paths', (
    tester,
  ) async {
    _viewport(tester);
    final targets = [
      initialCampaign.stageById('r01-c05-s01')!,
      initialCampaign.stageById('r01-c06-s01')!,
    ];
    final store = MemoryKeyValueSaveStore();
    await ProgressRepository(
      store,
      initialFactory: () => SaveEnvelopeV1(
        unlockedStageIds: targets.map((stage) => stage.id),
        completedStageIds: targets.map(
          (stage) => stage.recurrencePlan!.sourceStageId,
        ),
      ),
    ).update((save) => save.copyWith(viewedStoryIds: const ['fixture-ready']));
    await _boot(tester, store, DateTime(2026, 10, 11));
    await _tap(tester, find.text('계산의 평원'), 'R1 chapter gates');
    for (var index = 0; index < targets.length; index++) {
      await _tap(tester, find.text(index == 0 ? '공방' : '심화'), 'gated tab');
      final tile = find.ancestor(
        of: find.text('S01 · ${targets[index].title}'),
        matching: find.byType(ListTile),
      );
      expect(tile, findsOneWidget);
      expect(tester.widget<ListTile>(tile).onTap, isNull);
      expect(find.byType(DiscoveryPuzzleScreen), findsNothing);
    }
    expect((await ProgressRepository(store).load()).rewardLedger, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
