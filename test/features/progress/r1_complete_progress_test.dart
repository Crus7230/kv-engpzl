import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/campaign/domain/campaign_models.dart';
import 'package:kvm/features/garden/data/garden_catalog.dart';
import 'package:kvm/features/progress/data/progress_repository.dart';
import 'package:kvm/features/progress/domain/daily_route_service.dart';
import 'package:kvm/features/progress/domain/progress_models.dart';
import 'package:kvm/features/progress/domain/stage_completion_service.dart';

StageDefinition _stage(String id) => initialCampaign.stageById(id)!;

StageAttemptResult _success(StageDefinition stage) => StageAttemptResult(
  attemptId: 'complete-${stage.id}',
  stage: stage,
  completedAt: DateTime(2026, 10, 11),
  metrics: StageAttemptMetrics(
    completed: true,
    movesUsed: stage.moveBudget.referenceMoves,
    meaningfulSubmissionCount: 1,
    firstMeaningfulSubmissionCorrect: true,
    highestMathHintTierUsed: 3,
    usedDirectPathHint: true,
    usedGuidedCompletion: true,
  ),
);

Future<void> _completeCore(StageCompletionService service) async {
  for (final chapter in initialCampaign.regions.first.chapters.take(3)) {
    for (final stage in chapter.stages) {
      await service.complete(_success(stage));
    }
  }
}

void main() {
  test('R1 projects map all 24 milestones without changing old IDs', () {
    final region = initialCampaign.regions.first;
    final garden = gardenDefinitionByRegionId(region.id)!;
    expect(garden.projectScenes, hasLength(6));
    expect(garden.restorationNodes, hasLength(24));
    expect(
      r1CharacterStories.map((story) => story.characterId).toSet(),
      region.featuredCharacterIds.toSet(),
    );
    for (final node in garden.restorationNodes) {
      expect(_stage(node.requiredStageId).isPlayable, isTrue);
      expect(garden.sceneByChapterId(node.chapterId!)!.id, node.sceneId);
      expect(node.storyId, '${node.id}-story');
      expect(node.storyText, isNotEmpty);
    }
  });

  test(
    'early C04 finale does not open C05 until all previous chapters finish',
    () async {
      final repository = ProgressRepository(MemoryKeyValueSaveStore());
      final service = StageCompletionService(
        repository,
        campaign: initialCampaign,
      );
      await _completeCore(service);
      final earlyFinale = await service.complete(
        _success(_stage('r01-c04-s10')),
      );
      expect(earlyFinale.nextStageId, 'r01-c04-s01');
      expect(
        (await repository.load()).unlockedStageIds,
        isNot(contains('r01-c05-s01')),
      );
      CompletionReceipt? last;
      for (var number = 1; number <= 9; number++) {
        last = await service.complete(
          _success(_stage('r01-c04-s${number.toString().padLeft(2, '0')}')),
        );
      }
      expect(last!.nextStageId, 'r01-c05-s01');
      expect(
        (await repository.load()).unlockedStageIds,
        contains('r01-c05-s01'),
      );
    },
  );

  test('persisted C05/C06 unlock IDs cannot bypass chapter gates', () async {
    for (final stageId in ['r01-c05-s01', 'r01-c06-s01']) {
      final target = _stage(stageId);
      final repository = ProgressRepository(
        MemoryKeyValueSaveStore(),
        initialFactory: () => SaveEnvelopeV1(
          unlockedStageIds: [target.id],
          completedStageIds: [target.recurrencePlan!.sourceStageId],
        ),
      );
      final route = const DailyRouteService().build(
        await repository.load(),
        initialCampaign,
      );
      expect(route.explorationStage, isNull);
      expect(route.reviewStage, isNull);
      await expectLater(
        StageCompletionService(
          repository,
          campaign: initialCampaign,
        ).complete(_success(target)),
        throwsStateError,
      );
      expect((await repository.load()).rewardLedger, isEmpty);
    }
  });

  test(
    'character milestones are guaranteed and idempotent after reload',
    () async {
      final store = MemoryKeyValueSaveStore();
      final repository = ProgressRepository(store);
      final service = StageCompletionService(
        repository,
        campaign: initialCampaign,
      );
      expect((await repository.load()).unlockedCharacterIds, {
        'CHAR_D',
        'CHAR_J',
      });
      CompletionReceipt? receipt;
      for (final chapter in initialCampaign.regions.first.chapters.take(2)) {
        for (final stage in chapter.stages) {
          receipt = await service.complete(_success(stage));
        }
      }
      expect(receipt!.unlockedCharacterIds, ['CHAR_L']);
      final reloaded = ProgressRepository(store);
      final original = await reloaded.load();
      final duplicate = await StageCompletionService(
        reloaded,
        campaign: initialCampaign,
      ).complete(_success(_stage('r01-c02-s10')));
      expect(duplicate.unlockedCharacterIds, ['CHAR_L']);
      expect((await reloaded.load()).generation, original.generation);
      expect((await reloaded.load()).viewedStoryIds, isEmpty);
      for (final stage in initialCampaign.regions.first.chapters[2].stages) {
        receipt = await StageCompletionService(
          reloaded,
          campaign: initialCampaign,
        ).complete(_success(stage));
      }
      expect(receipt!.unlockedCharacterIds, ['CHAR_U']);
      expect((await reloaded.load()).unlockedCharacterIds, {
        'CHAR_D',
        'CHAR_J',
        'CHAR_L',
        'CHAR_U',
      });
    },
  );

  test('R1 end honestly leaves no new stage but offers daily replay', () async {
    final repository = ProgressRepository(MemoryKeyValueSaveStore());
    final service = StageCompletionService(
      repository,
      campaign: initialCampaign,
    );
    for (final stage in initialCampaign.regions.first.stages) {
      await service.complete(_success(stage));
    }
    final snapshot = await repository.load();
    final route = const DailyRouteService().build(
      snapshot,
      initialCampaign,
      now: DateTime(2026, 10, 12),
    );
    expect(route.completedPlayableStageCount, 60);
    expect(route.playableStageCount, 60);
    expect(route.completedRegionIds, {'region-01-calculation'});
    expect(route.campaignCompleted, isFalse);
    expect(route.explorationStage, isNull);
    expect(route.reviewStage, isNotNull);
    expect(snapshot.unlockedStageIds, contains('r02-c01-s01'));
    expect(
      snapshot.rewardLedger.values
          .expand((receipt) => receipt.unlockedRestorationNodeIds)
          .toSet(),
      hasLength(24),
    );
  });

  test('old completion receipt migrates absent character rewards as empty', () {
    final json = CompletionReceipt(
      attemptId: 'old-receipt',
      stageId: 'r01-c01-s01',
      stars: 1,
      firstCompletion: true,
      supportReviewNeeded: false,
    ).toJson()..remove('unlockedCharacterIds');
    expect(CompletionReceipt.fromJson(json).unlockedCharacterIds, isEmpty);
  });

  test(
    'the previous 25-stage save continues without repeating finished reviews',
    () async {
      final store = MemoryKeyValueSaveStore();
      final originalRepository = ProgressRepository(store);
      final originalService = StageCompletionService(
        originalRepository,
        campaign: initialCampaign,
      );
      final region = initialCampaign.regions.first;
      for (final stage in region.chapters.first.stages) {
        await originalService.complete(_success(stage));
      }
      for (final stage in region.chapters[1].stages.take(5)) {
        await originalService.complete(_success(stage));
      }
      for (final stage in region.chapters[3].stages) {
        await originalService.complete(_success(stage));
      }
      final oldSave = await originalRepository.load();
      expect(oldSave.completedStageIds, hasLength(25));
      expect(oldSave.unlockedStageIds, isNot(contains('r01-c05-s01')));
      final afterUpdate = ProgressRepository(store);
      final next = const DailyRouteService().build(
        await afterUpdate.load(),
        initialCampaign,
      );
      expect(next.explorationStage!.id, 'r01-c02-s06');
      final newService = StageCompletionService(
        afterUpdate,
        campaign: initialCampaign,
      );
      for (final stage in region.chapters[1].stages.skip(5)) {
        await newService.complete(_success(stage));
      }
      CompletionReceipt? finalCore;
      for (final stage in region.chapters[2].stages) {
        finalCore = await newService.complete(_success(stage));
      }
      expect(finalCore!.nextStageId, 'r01-c05-s01');
      final updated = await afterUpdate.load();
      expect(updated.rewardLedger.keys, containsAll(oldSave.rewardLedger.keys));
      expect(updated.completedStageIds, hasLength(40));
      expect(updated.bestStars.keys, containsAll(oldSave.bestStars.keys));
    },
  );
}
