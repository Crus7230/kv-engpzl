import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/campaign/domain/campaign_models.dart';
import 'package:kvm/features/companions/companions.dart';
import 'package:kvm/features/progress/progress.dart';

StageAttemptResult _success(String id) {
  final stage = initialCampaign.stageById(id)!;
  return StageAttemptResult(
    attemptId: 'rescue-$id',
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
}

SaveEnvelopeV1 _selected(String id) => SaveEnvelopeV1.initial().copyWith(
  playerCharacterId: id,
  unlockedCharacterIds: [id],
  onboardingCompleted: true,
);

void main() {
  test(
    'new expedition requires selection; explicit current-epoch saves round trip',
    () {
      final fresh = SaveEnvelopeV1.initial();
      expect(fresh.playerCharacterId, isNull);
      expect(fresh.unlockedCharacterIds, isEmpty);
      expect(fresh.onboardingCompleted, isFalse);
      expect(
        SaveEnvelopeV1.fromJson(fresh.toJson()).onboardingCompleted,
        isFalse,
      );

      final current = _selected('CHAR_D').copyWith(
        completedStageIds: ['r01-c01-s03', 'future-stage'],
        unlockedCharacterIds: [
          'CHAR_D',
          'CHAR_J',
          'CHAR_L',
          'CHAR_U',
          'future-owner',
        ],
        restoredNodeIds: ['r01-c01-garden-02'],
        viewedStoryIds: ['r01-character-j-intro', 'r01-c01-garden-02-story'],
        bestStars: {'r01-c01-s03': 3},
        decorationChoices: {'r01-c01-garden-02': 'stone-path'},
        activeSession: {
          'stageId': 'r01-c01-s04',
          'board': [1, 2],
          'draft': '3+',
        },
      );
      final decoded = SaveEnvelopeV1.fromJson(current.toJson());
      expect(decoded.playerCharacterId, 'CHAR_D');
      expect(decoded.onboardingCompleted, isTrue);
      expect(decoded.unlockedCharacterIds, current.unlockedCharacterIds);
      expect(decoded.completedStageIds, current.completedStageIds);
      expect(decoded.restoredNodeIds, current.restoredNodeIds);
      expect(decoded.viewedStoryIds, current.viewedStoryIds);
      expect(decoded.bestStars, current.bestStars);
      expect(decoded.decorationChoices, current.decorationChoices);
      expect(decoded.activeSession, current.activeSession);
      expect(decoded.schemaVersion, 1);
      expect(decoded.contentVersion, current.contentVersion);
    },
  );

  test(
    'missing onboarding fields never infer a player or tutorial completion',
    () {
      final incompleteJson =
          _selected('CHAR_D')
              .copyWith(
                unlockedCharacterIds: ['CHAR_D', 'CHAR_J', 'CHAR_L', 'CHAR_U'],
                completedStageIds: ['r01-c01-s01'],
              )
              .toJson()
            ..remove('playerCharacterId')
            ..remove('onboardingCompleted');
      final decoded = SaveEnvelopeV1.fromJson(incompleteJson);
      expect(decoded.playerCharacterId, isNull);
      expect(decoded.onboardingCompleted, isFalse);
    },
  );

  test('R1 rescues occur at authored chapter milestones, once only', () async {
    final store = MemoryKeyValueSaveStore();
    final repository = ProgressRepository(
      store,
      initialFactory: () => _selected('CHAR_A'),
    );
    final completion = StageCompletionService(
      repository,
      campaign: initialCampaign,
    );
    final companionService = CompanionProgressService(repository);
    expect(nextUnviewedCompanionArrival(await repository.load()), isNull);
    CompletionReceipt? receipt;
    for (final stage in initialCampaign.regions.first.stages) {
      receipt = await completion.complete(_success(stage.id));
      final expectedNew = switch (stage.id) {
        'r01-c01-s10' => ['CHAR_D', 'CHAR_J'],
        'r01-c03-s10' => ['CHAR_L'],
        'r01-c05-s10' => ['CHAR_U'],
        _ => <String>[],
      };
      expect(receipt.unlockedCharacterIds, expectedNew, reason: stage.id);
      if (stage.id == 'r01-c01-s10') {
        final before = await repository.load();
        final duplicate = await completion.complete(_success(stage.id));
        expect(duplicate.unlockedCharacterIds, ['CHAR_D', 'CHAR_J']);
        expect((await repository.load()).generation, before.generation);
        expect(nextUnviewedCompanionArrival(before)!.characterId, 'CHAR_D');
        final viewed = await companionService.markArrivalViewed('CHAR_D');
        expect(nextUnviewedCompanionArrival(viewed)!.characterId, 'CHAR_J');
        final idempotent = await companionService.markArrivalViewed('CHAR_D');
        expect(idempotent.generation, viewed.generation);
        expect(idempotent.rewardLedger, viewed.rewardLedger);
        expect(idempotent.bestStars, viewed.bestStars);
        await companionService.markArrivalViewed('CHAR_J');
      }
    }
    final reloaded = await ProgressRepository(store).load();
    expect(reloaded.playerCharacterId, 'CHAR_A');
    expect(reloaded.unlockedCharacterIds, {
      'CHAR_A',
      'CHAR_D',
      'CHAR_J',
      'CHAR_L',
      'CHAR_U',
    });
    expect(reloaded.rewardLedger, hasLength(60));
    expect(
      reloaded.viewedStoryIds,
      containsAll(['expedition-join-CHAR_D', 'expedition-join-CHAR_J']),
    );
    expect(receipt!.stageId, 'r01-c06-s10');
  });

  test(
    'choosing one rescued character grants only the other; player is not a new arrival',
    () async {
      for (final playerId in ['CHAR_D', 'CHAR_J']) {
        final repository = ProgressRepository(
          MemoryKeyValueSaveStore(),
          initialFactory: () => _selected(playerId),
        );
        final completion = StageCompletionService(
          repository,
          campaign: initialCampaign,
        );
        CompletionReceipt? receipt;
        for (final stage
            in initialCampaign.regions.first.chapters.first.stages) {
          receipt = await completion.complete(_success(stage.id));
        }
        final otherId = playerId == 'CHAR_D' ? 'CHAR_J' : 'CHAR_D';
        expect(receipt!.unlockedCharacterIds, [otherId]);
        expect(
          nextUnviewedCompanionArrival(await repository.load())!.characterId,
          otherId,
        );
        await expectLater(
          CompanionProgressService(repository).markArrivalViewed(playerId),
          throwsStateError,
        );
      }
    },
  );

  test(
    'current-epoch owners stay owned and replayed scenes do not grant rewards',
    () async {
      final old = _selected('CHAR_D').copyWith(
        unlockedCharacterIds: [
          'CHAR_D',
          'CHAR_J',
          'CHAR_L',
          'CHAR_U',
          'CHAR_Z',
        ],
        viewedStoryIds: ['r01-character-j-intro'],
        completedStageIds: ['r01-c01-s10'],
        bestStars: {'r01-c01-s10': 3},
        activeSession: {'draft': '4+'},
      );
      final repository = ProgressRepository(
        MemoryKeyValueSaveStore(),
        initialFactory: () => old,
      );
      final service = CompanionProgressService(repository);
      final unchanged = await service.reconcileEligibility();
      expect(unchanged.generation, 0);
      expect(unchanged.unlockedCharacterIds, old.unlockedCharacterIds);
      expect(nextUnviewedCompanionArrival(unchanged)!.characterId, 'CHAR_J');
      final viewed = await service.markArrivalViewed('CHAR_J');
      expect(
        viewed.viewedStoryIds,
        containsAll(['r01-character-j-intro', 'expedition-join-CHAR_J']),
      );
      expect(viewed.bestStars, old.bestStars);
      expect(viewed.rewardLedger, old.rewardLedger);
      expect(viewed.activeSession, old.activeSession);
      expect(viewed.unlockedCharacterIds, old.unlockedCharacterIds);
      await expectLater(service.markArrivalViewed('CHAR_L'), throwsStateError);
      await expectLater(service.markArrivalViewed('CHAR_Z'), throwsStateError);
    },
  );

  test(
    'planned territories cannot grant rescues from persisted future IDs',
    () {
      final future = companionRecruitmentPlan.where(
        (entry) => entry.regionNumber > 2,
      );
      final completed = {for (final entry in future) entry.requiredStageId!};
      expect(companionOwnershipAfterProgress({'CHAR_D'}, completed), {
        'CHAR_D',
      });
      for (final entry in future) {
        expect(entry.available, isFalse);
        expect(isCompanionRecruitmentEligible(entry, completed), isFalse);
      }
    },
  );

  test(
    'early arrival rejection cannot modify selection or persisted progress',
    () async {
      final repository = ProgressRepository(
        MemoryKeyValueSaveStore(),
        initialFactory: () => _selected('CHAR_A'),
      );
      final service = CompanionProgressService(repository);
      await expectLater(service.markArrivalViewed('CHAR_J'), throwsStateError);
      final after = await repository.load();
      expect(after.generation, 0);
      expect(after.playerCharacterId, 'CHAR_A');
      expect(after.unlockedCharacterIds, {'CHAR_A'});
      expect(after.viewedStoryIds, isEmpty);
    },
  );
}
