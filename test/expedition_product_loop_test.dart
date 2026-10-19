import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/app/math_adventure_app.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/campaign/data/r1_authored_campaign.dart';
import 'package:kvm/features/companions/companions.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_screen.dart';
import 'package:kvm/features/discovery/presentation/stage_session_controller.dart';
import 'package:kvm/features/garden/presentation/garden_screens.dart';
import 'package:kvm/features/onboarding/presentation/expedition_onboarding_screen.dart';
import 'package:kvm/features/progress/progress.dart';

void _viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 360);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _boot(WidgetTester tester, MemoryKeyValueSaveStore store) async {
  await tester.pumpWidget(
    MathAdventureApp(
      repository: ProgressRepository(store),
      assetBundle: rootBundle,
      now: () => DateTime(2026, 10, 11),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

StageSessionController _session(WidgetTester tester) =>
    tester
            .widget<DiscoveryPuzzleScreen>(find.byType(DiscoveryPuzzleScreen))
            .viewModel!
        as StageSessionController;

void _excavate(StageSessionController model) {
  for (final swap in model.referencePath) {
    model.selectGem(swap.from.row * model.boardColumns + swap.from.column);
    model.selectGem(swap.to.row * model.boardColumns + swap.to.column);
  }
}

Future<void> _solve(WidgetTester tester, StageSessionController model) async {
  _excavate(model);
  for (final id in r1AnswerTokenIdsByStageId[model.stage.id]!) {
    if (!model.answerBlocks.any((block) => block.id == id))
      model.addBlockToAnswer(id);
  }
  model.checkAnswer();
  expect(model.isAnswerCorrect, isTrue);
  await model.flush();
  await tester.pumpAndSettle();
  await _tap(tester, find.text('결과 보기'));
  expect(find.byType(StageResultScreen), findsOneWidget);
}

void main() {
  testWidgets(
    'new player choice, real tutorial, checkpoint restart and departure',
    (tester) async {
      _viewport(tester);
      final store = MemoryKeyValueSaveStore();
      await _boot(tester, store);
      expect(find.byType(ExpeditionOnboardingScreen), findsOneWidget);
      expect(find.byType(WorldMapScreen), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('onboarding-player-CHAR_J')),
        80,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('onboarding-player-grid')),
          matching: find.byType(Scrollable),
        ),
      );
      await _tap(
        tester,
        find.byKey(const ValueKey('onboarding-player-CHAR_J')),
      );
      await _tap(
        tester,
        find.byKey(const ValueKey('onboarding-primary-action')),
      );
      var save = await ProgressRepository(store).load();
      expect(save.playerCharacterId, 'CHAR_J');
      expect(save.unlockedCharacterIds, {'CHAR_J'});
      expect(save.completedStageIds, isEmpty);
      expect(save.rewardLedger, isEmpty);
      expect(save.onboardingCompleted, isFalse);
      await _tap(tester, find.text('첫 문제 풀어보기'));
      await _tap(tester, find.text('탐험 시작하기'));
      var model = _session(tester);
      expect(model.stage.id, 'r01-c01-s01');
      _excavate(model);
      model.addBlockToAnswer(r1AnswerTokenIdsByStageId[model.stage.id]!.first);
      await model.checkpoint();
      final snapshot = (await ProgressRepository(store).load()).activeSession!;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ExpeditionOnboardingScreen), findsOneWidget);
      expect(find.byType(WorldMapScreen), findsNothing);
      expect(find.text('첫 문제 이어서 풀기'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await _boot(tester, store);
      expect(find.text('첫 문제 이어서 풀기'), findsOneWidget);
      await _tap(tester, find.text('첫 문제 이어서 풀기'));
      await _tap(tester, find.text('이어서 탐험하기'));
      model = _session(tester);
      expect(
        model.exportSession(),
        containsPair('boardState', snapshot['boardState']),
      );
      expect(model.answerBlocks.map((block) => block.id), [
        r1AnswerTokenIdsByStageId[model.stage.id]!.first,
      ]);
      expect(model.attemptId, snapshot['attemptId']);
      // Continue the saved equation without issuing the already completed swaps.
      for (final id in r1AnswerTokenIdsByStageId[model.stage.id]!.skip(1)) {
        model.addBlockToAnswer(id);
      }
      model.checkAnswer();
      expect(model.isAnswerCorrect, isTrue);
      await model.flush();
      await tester.pumpAndSettle();
      await _tap(tester, find.text('결과 보기'));
      save = await ProgressRepository(store).load();
      expect(save.completedStageIds, {'r01-c01-s01'});
      expect(save.rewardLedger, hasLength(1));
      expect(save.unlockedStageIds, contains('r01-c01-s02'));
      expect(save.activeSession, isNull);
      expect(save.onboardingCompleted, isFalse);
      // A termination after completion does not repeat tutorial rewards.
      await tester.pumpWidget(const SizedBox.shrink());
      await _boot(tester, store);
      expect(find.text('계산의 평원으로 출발'), findsOneWidget);
      await _tap(tester, find.text('계산의 평원으로 출발'));
      expect(find.byType(CampaignRegionGardenScreen), findsOneWidget);
      save = await ProgressRepository(store).load();
      expect(save.onboardingCompleted, isTrue);
      expect(save.rewardLedger, hasLength(1));
      expect(save.unlockedCharacterIds, {'CHAR_J'});
      await tester.pumpWidget(const SizedBox.shrink());
      await _boot(tester, store);
      expect(find.byType(WorldMapScreen), findsOneWidget);
      expect(find.byType(ExpeditionOnboardingScreen), findsNothing);
      expect(
        (await ProgressRepository(store).load()).rewardLedger,
        hasLength(1),
      );
    },
  );

  testWidgets(
    'chapter arrival queue survives restart and collection replay grants nothing',
    (tester) async {
      _viewport(tester);
      final completed = initialCampaign.regions.first.chapters.first.stages
          .take(9)
          .map((s) => s.id)
          .toSet();
      final store = MemoryKeyValueSaveStore();
      await ProgressRepository(store).save(
        SaveEnvelopeV1.initial().copyWith(
          completedStageIds: completed,
          unlockedStageIds: {...completed, 'r01-c01-s10'},
          playerCharacterId: 'CHAR_X',
          onboardingCompleted: true,
          unlockedCharacterIds: {'CHAR_X'},
        ),
      );
      await _boot(tester, store);
      await _tap(tester, find.byKey(const ValueKey('world-explore')));
      await _tap(tester, find.text('탐험 시작하기'));
      expect(_session(tester).stage.id, 'r01-c01-s10');
      await _solve(tester, _session(tester));
      await _tap(tester, find.text('탐험의 흔적 남기기'));
      await _tap(tester, find.text('탐험을 계속하기'));
      var arrival = tester.widget<CompanionArrivalScreen>(
        find.byType(CompanionArrivalScreen),
      );
      expect(arrival.recruitment.characterId, 'CHAR_D');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(CompanionArrivalScreen), findsNothing);
      expect(find.byType(CampaignRegionGardenScreen), findsOneWidget);
      expect(
        (await ProgressRepository(store).load()).viewedStoryIds,
        isNot(contains('expedition-join-CHAR_D')),
      );
      tester
          .widget<CampaignRegionGardenScreen>(
            find.byType(CampaignRegionGardenScreen),
          )
          .onBack();
      await tester.pumpAndSettle();
      tester
          .widget<WorldMapScreen>(find.byType(WorldMapScreen))
          .onSelectRegion('region-01-calculation');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CompanionArrivalScreen>(find.byType(CompanionArrivalScreen))
            .recruitment
            .characterId,
        'CHAR_D',
      );
      await _tap(tester, find.byKey(const Key('companion-arrival-continue')));
      arrival = tester.widget<CompanionArrivalScreen>(
        find.byType(CompanionArrivalScreen),
      );
      expect(arrival.recruitment.characterId, 'CHAR_J');
      await tester.pumpWidget(const SizedBox.shrink());
      await _boot(tester, store);
      tester
          .widget<WorldMapScreen>(find.byType(WorldMapScreen))
          .onSelectRegion('region-01-calculation');
      await tester.pumpAndSettle();
      arrival = tester.widget<CompanionArrivalScreen>(
        find.byType(CompanionArrivalScreen),
      );
      expect(arrival.recruitment.characterId, 'CHAR_J');
      await _tap(tester, find.byKey(const Key('companion-arrival-continue')));
      expect(find.byType(CampaignRegionGardenScreen), findsOneWidget);
      final before = await ProgressRepository(store).load();
      expect(before.unlockedCharacterIds, {'CHAR_X', 'CHAR_D', 'CHAR_J'});
      expect(
        before.viewedStoryIds,
        containsAll(['expedition-join-CHAR_D', 'expedition-join-CHAR_J']),
      );
      tester
          .widget<CampaignRegionGardenScreen>(
            find.byType(CampaignRegionGardenScreen),
          )
          .onCompanions!();
      await tester.pumpAndSettle();
      var collection = tester.widget<CompanionCollectionScreen>(
        find.byType(CompanionCollectionScreen),
      );
      expect(collection.save.playerCharacterId, 'CHAR_X');
      collection.onReplayArrival!('CHAR_D');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CompanionArrivalScreen>(find.byType(CompanionArrivalScreen))
            .replay,
        isTrue,
      );
      await _tap(tester, find.byKey(const Key('companion-arrival-continue')));
      collection = tester.widget<CompanionCollectionScreen>(
        find.byType(CompanionCollectionScreen),
      );
      expect(
        (await ProgressRepository(store).load()).toJson(),
        before.toJson(),
      );
      collection.onBack();
      await tester.pumpAndSettle();
      expect(find.byType(CampaignRegionGardenScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'approved save epoch reset ignores old progress and requires onboarding once',
    (tester) async {
      _viewport(tester);
      final legacy =
          SaveEnvelopeV1.initial()
              .copyWith(
                completedStageIds: {'r01-c01-s01'},
                unlockedStageIds: {'r01-c01-s01', 'r01-c01-s02'},
                unlockedCharacterIds: {
                  'CHAR_D',
                  'CHAR_J',
                  'unrecognized-legacy-owner',
                },
                bestStars: {'r01-c01-s01': 3},
                viewedStoryIds: {'r01-char-d-story'},
                decorationChoices: {'preserved-legacy-node': 'herbs'},
                activeSession: {
                  'stageId': 'r01-c01-s02',
                  'legacy-marker': ['preserve'],
                },
              )
              .toJson()
            ..remove('playerCharacterId')
            ..remove('onboardingCompleted');
      final store = MemoryKeyValueSaveStore({
        'kvm.renewal.save.v1.active': 'a',
        'kvm.renewal.save.v1.slot.a': jsonEncode(legacy),
      });
      final raw = {...store.values};
      await _boot(tester, store);
      expect(find.byType(WorldMapScreen), findsNothing);
      expect(find.byType(ExpeditionOnboardingScreen), findsOneWidget);
      final fresh = await ProgressRepository(store).load();
      expect(fresh.playerCharacterId, isNull);
      expect(fresh.onboardingCompleted, isFalse);
      expect(fresh.completedStageIds, isEmpty);
      expect(fresh.unlockedCharacterIds, isEmpty);
      expect(fresh.rewardLedger, isEmpty);
      expect(fresh.bestStars, isEmpty);
      expect(fresh.activeSession, isNull);
      expect(store.values, raw);
      await _tap(tester, find.text('이 탐험가로 시작'));
      expect(
        (await ProgressRepository(store).load()).playerCharacterId,
        'CHAR_D',
      );
      expect(
        store.values['kvm.renewal.save.v1.slot.a'],
        raw['kvm.renewal.save.v1.slot.a'],
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await _boot(tester, store);
      expect(find.text('첫 문제 풀어보기'), findsOneWidget);
      expect(find.text('나의 탐험가를 골라요'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
