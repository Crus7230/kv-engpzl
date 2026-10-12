import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/campaign/domain/campaign_models.dart';
import 'package:kvm/features/companions/companions.dart';
import 'package:kvm/features/garden/data/garden_catalog.dart';
import 'package:kvm/features/progress/progress.dart';

StageAttemptResult _success(StageDefinition stage) => StageAttemptResult(
  attemptId: 'r2-expansion-${stage.id}',
  stage: stage,
  completedAt: DateTime(2026, 10, 12),
  metrics: StageAttemptMetrics(
    completed: true,
    movesUsed: stage.moveBudget.referenceMoves,
    meaningfulSubmissionCount: 1,
    firstMeaningfulSubmissionCorrect: true,
    highestMathHintTierUsed: 3,
    usedDirectPathHint: false,
    usedGuidedCompletion: true,
  ),
);

void main() {
  test(
    'catalog update adds missed R2 unlock without resetting evidence/session',
    () async {
      final store = MemoryKeyValueSaveStore();
      final old = SaveEnvelopeV1(
        completedStageIds: const {'r01-c03-s10'},
        unlockedStageIds: const {'r01-c01-s01'},
        bestStars: const {'r01-c03-s10': 2},
        restoredNodeIds: const {'r01-c03-garden-10'},
        decorationChoices: const {'r01-c03-garden-10': 'herbs'},
        playerCharacterId: 'CHAR_D',
        onboardingCompleted: true,
        activeSession: const {
          'stageId': 'r01-c02-s05',
          'attemptId': 'old-attempt',
          'sessionVersion': 1,
        },
        dailyActions: const {'2026-10-11': 1},
      );
      final repository = ProgressRepository(store, initialFactory: () => old);
      final service = CampaignContentUpdateService(repository, initialCampaign);
      final updated = await service.reconcileUnlocks();
      expect(updated.unlockedStageIds, contains('r02-c01-s01'));
      expect(updated.completedStageIds, old.completedStageIds);
      expect(updated.bestStars, old.bestStars);
      expect(updated.restoredNodeIds, old.restoredNodeIds);
      expect(updated.decorationChoices, old.decorationChoices);
      expect(updated.activeSession, old.activeSession);
      expect(updated.rewardLedger, old.rewardLedger);
      expect(updated.skillProgress, old.skillProgress);
      expect(updated.dailyActions, old.dailyActions);
      expect(updated.playerCharacterId, 'CHAR_D');
      expect(updated.onboardingCompleted, isTrue);
      expect((await service.reconcileUnlocks()).generation, updated.generation);
      final reopened = await ProgressRepository(store).load();
      expect(reopened.activeSession, old.activeSession);
      expect(reopened.unlockedStageIds, contains('r02-c01-s01'));
      expect(ProgressRepository.saveEpoch, 'expedition-1');
    },
  );

  test(
    '120 completion transactions connect R2 review, traces and rescues',
    () async {
      final store = MemoryKeyValueSaveStore();
      final repository = ProgressRepository(store);
      final service = StageCompletionService(
        repository,
        campaign: initialCampaign,
      );
      for (final region in initialCampaign.regions.take(2)) {
        for (final stage in region.stages) {
          final result = _success(stage);
          final receipt = await service.complete(result);
          final generation = (await repository.load()).generation;
          expect((await service.complete(result)).toJson(), receipt.toJson());
          expect((await repository.load()).generation, generation);
          final snapshot = await repository.load();
          final next = const DailyRouteService()
              .build(snapshot, initialCampaign, now: DateTime(2026, 10, 12))
              .explorationStage;
          if (snapshot.completedStageIds.length < 120)
            expect(next, isNotNull, reason: stage.id);
        }
      }
      final save = await repository.load();
      expect(save.completedStageIds, hasLength(120));
      expect(save.rewardLedger, hasLength(120));
      expect(
        save.rewardLedger.values
            .expand((r) => r.unlockedRestorationNodeIds)
            .toSet(),
        hasLength(48),
      );
      expect(
        save.unlockedCharacterIds,
        containsAll(['CHAR_B', 'CHAR_F', 'CHAR_R', 'CHAR_N']),
      );
      final garden = gardenDefinitionByRegionId('region-02-pattern')!;
      expect(garden.projectScenes, hasLength(6));
      expect(garden.restorationNodes, hasLength(24));
      expect(
        garden.restorationNodes.every(
          (n) => n.storyText != null && n.sceneId != null,
        ),
        isTrue,
      );
      final nextDay = const DailyRouteService().build(
        save,
        initialCampaign,
        now: DateTime(2026, 10, 13),
      );
      expect(nextDay.explorationStage, isNull);
      expect(nextDay.reviewStage, isNotNull);
      expect(nextDay.playableStageCount, 120);
      expect(nextDay.completedRegionIds, {
        'region-01-calculation',
        'region-02-pattern',
      });
      expect(nextDay.campaignCompleted, isFalse);
      final arrivals = companionRecruitmentPlan
          .where((r) => r.regionNumber == 2)
          .toList();
      expect(arrivals.map((r) => r.characterId), [
        'CHAR_B',
        'CHAR_F',
        'CHAR_R',
        'CHAR_N',
      ]);
      expect(arrivals.map((r) => r.requiredStageId), [
        'r02-c01-s10',
        'r02-c01-s10',
        'r02-c03-s10',
        'r02-c05-s10',
      ]);
    },
  );
}
