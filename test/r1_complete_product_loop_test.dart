import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/app/math_adventure_app.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/campaign/data/r1_authored_campaign.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_screen.dart';
import 'package:kvm/features/discovery/presentation/stage_session_controller.dart';
import 'package:kvm/features/garden/data/garden_catalog.dart';
import 'package:kvm/features/garden/domain/garden_models.dart';
import 'package:kvm/features/garden/presentation/garden_screens.dart';
import 'package:kvm/features/garden/presentation/adventure_collection_screens.dart';
import 'package:kvm/features/companions/presentation/companion_screens.dart';
import 'package:kvm/features/exploration/data/r1_expedition_catalog.dart';
import 'package:kvm/features/progress/progress.dart';

void _viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 360);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

SaveEnvelopeV1 _existingPlayer(SaveEnvelopeV1 save) => save.copyWith(
  playerCharacterId: 'CHAR_D',
  onboardingCompleted: true,
  unlockedCharacterIds: {...save.unlockedCharacterIds, 'CHAR_D', 'CHAR_J'},
);

Future<void> _boot(
  WidgetTester tester,
  MemoryKeyValueSaveStore store,
  DateTime now,
) async {
  await tester.pumpWidget(
    MathAdventureApp(
      repository: ProgressRepository(
        store,
        initialFactory: () => _existingPlayer(SaveEnvelopeV1.initial()),
      ),
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
  // Real runtime swaps and answer submissions drive the app's session/save
  // controller. This is not a pre-completed save or a completion-service stub.
  for (final swap in model.referencePath) {
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
  expect(find.text(expeditionMilestoneTitle(node)), findsOneWidget);
  await _tap(tester, find.text(expeditionDecorationLabel(decoration)), node.id);
  await _tap(tester, find.text('탐험을 계속하기'), '${node.id} finish discovery');
  while (find.byType(CompanionArrivalScreen).evaluate().isNotEmpty) {
    await _tap(
      tester,
      find.byKey(const Key('companion-arrival-continue')),
      '${node.id} companion arrival',
    );
  }
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
      await _tap(
        tester,
        find.byKey(const ValueKey('world-explore')),
        'first daily exploration',
      );
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
            find.text('탐험의 흔적 남기기'),
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
      expect(find.text('평원 탐험 완료 · 모험 지도에서 숲으로 출발하세요'), findsOneWidget);
      final completeGarden = tester.widget<CampaignRegionGardenScreen>(
        find.byType(CampaignRegionGardenScreen),
      );
      expect(completeGarden.onPlay, isNull);
      expect(find.text('지역 탐험 완료'), findsOneWidget);

      // Every destination tab retains its original ten stable stage nodes.
      final labels = ['입구', '수확길', '수문', '기억길', '공방', '전망대'];
      for (var chapter = 0; chapter < labels.length; chapter++) {
        await _tap(
          tester,
          find.text(labels[chapter]),
          'project ${labels[chapter]}',
        );
        expect(
          find.byKey(ValueKey('expedition-stage-r01-c0${chapter + 1}-s01')),
          findsOneWidget,
        );
      }

      // Read every unlocked character story. Merely unlocking a character did
      // not mark these stories viewed during the campaign completion loop.
      for (final story in r1CharacterStories) {
        expect(complete.viewedStoryIds, isNot(contains(story.id)));
        await _tap(tester, find.byTooltip('탐험 이야기'), '${story.id} chooser');
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
      await _tap(tester, find.text('탐험 흔적'), 'per-node decoration chooser');
      expect(find.text('탐험 흔적 고르기'), findsOneWidget);
      await _tap(
        tester,
        find.text(expeditionMilestoneTitle(firstNode)),
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

      // R2 is authored; R3 still has no executable route.
      await _tap(
        tester,
        find.byTooltip('탐험 지도에서 월드맵으로'),
        'trail back to world',
      );
      await _tap(
        tester,
        find.byTooltip('단위와 측정의 협곡 · 업데이트 예정'),
        'R3 update placeholder',
      );
      expect(find.text('업데이트 예정'), findsWidgets);
      expect(find.byType(DiscoveryPuzzleScreen), findsNothing);
      expect(find.byType(StageBriefingScreen), findsNothing);
      expect(find.text('체험 탐험하기'), findsNothing);
      await _tap(tester, find.text('월드맵으로'), 'return from R3');
      expect(
        tester.widget<WorldMapScreen>(find.byType(WorldMapScreen)).onExplore,
        isNotNull,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _boot(tester, store, DateTime(2026, 10, 12));
      final resumed = await ProgressRepository(store).load();
      expect(resumed.completedStageIds, afterDecoration.completedStageIds);
      expect(resumed.restoredNodeIds, afterDecoration.restoredNodeIds);
      expect(resumed.decorationChoices, afterDecoration.decorationChoices);
      expect(resumed.viewedStoryIds, afterDecoration.viewedStoryIds);
      expect(find.byTooltip('오늘의 탐험 · R02-C01 S01'), findsOneWidget);
      final world = tester.widget<WorldMapScreen>(find.byType(WorldMapScreen));
      expect(world.explorationDetail, 'R02-C01 S01');
      expect(world.onExplore, isNotNull);
      expect(world.onReview, isNotNull);

      // The next day's review is a real replay, not a falsely advertised new
      // stage. It must complete without duplicating garden restoration rewards.
      await _tap(
        tester,
        find.byKey(const ValueKey('world-review')),
        'next-day review',
      );
      await _tap(
        tester,
        find.byKey(const ValueKey('memory-seed-play')),
        'wake seed',
      );
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
      reviewResult.onBack();
      await tester.pumpAndSettle();
      expect(find.byType(MemorySeedsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    'a persisted future-region unlock never opens planned R3 gameplay',
    (tester) async {
      _viewport(tester);
      final store = MemoryKeyValueSaveStore();
      await ProgressRepository(
        store,
        initialFactory: () => _existingPlayer(
          SaveEnvelopeV1(
            unlockedStageIds: const ['r03-c01-s01'],
            completedStageIds: const ['r02-c03-s10'],
          ),
        ),
      ).update(
        (save) => save.copyWith(viewedStoryIds: const ['fixture-ready']),
      );
      await _boot(tester, store, DateTime(2026, 10, 11));
      final world = tester.widget<WorldMapScreen>(find.byType(WorldMapScreen));
      expect(world.onExplore, isNull);
      expect(world.availableRegionIds, isNot(contains('region-03-unit')));
      await _tap(
        tester,
        find.byTooltip('단위와 측정의 협곡 · 업데이트 예정'),
        'forced unlocked R3',
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
      initialFactory: () => _existingPlayer(
        SaveEnvelopeV1(
          unlockedStageIds: targets.map((stage) => stage.id),
          completedStageIds: targets.map(
            (stage) => stage.recurrencePlan!.sourceStageId,
          ),
        ),
      ),
    ).update((save) => save.copyWith(viewedStoryIds: const ['fixture-ready']));
    await _boot(tester, store, DateTime(2026, 10, 11));
    await _tap(tester, find.text('계산의 평원'), 'R1 chapter gates');
    for (var index = 0; index < targets.length; index++) {
      await _tap(tester, find.text(index == 0 ? '공방' : '전망대'), 'gated tab');
      final tile = find.byKey(
        ValueKey('expedition-stage-${targets[index].id}'),
      );
      expect(tile, findsOneWidget);
      expect(tester.widget<InkResponse>(tile).onTap, isNull);
      expect(find.byType(DiscoveryPuzzleScreen), findsNothing);
    }
    expect((await ProgressRepository(store).load()).rewardLedger, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
