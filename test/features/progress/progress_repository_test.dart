import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/campaign/domain/campaign_models.dart';
import 'package:kvm/features/campaign/domain/learning_models.dart';
import 'package:kvm/features/garden/data/garden_catalog.dart';
import 'package:kvm/features/progress/data/progress_repository.dart';
import 'package:kvm/features/progress/domain/daily_route_service.dart';
import 'package:kvm/features/progress/domain/progress_models.dart';
import 'package:kvm/features/progress/domain/stage_completion_service.dart';

class FailingStore extends MemoryKeyValueSaveStore {
  String? failingWriteKey;
  bool corruptSlotReadback = false;
  String? _lastWriteKey;
  @override
  Future<void> write(String key, String value) async {
    if (key == failingWriteKey) throw StateError('Injected write failure.');
    await super.write(key, value);
    _lastWriteKey = key;
  }

  @override
  Future<String?> read(String key) async {
    if (corruptSlotReadback &&
        _lastWriteKey == key &&
        key != ProgressRepository.pointerKey)
      return 'corrupt';
    return super.read(key);
  }
}

StageAttemptResult attempt(String id, {DateTime? at}) => StageAttemptResult(
  attemptId: id,
  stage: verticalSliceStage,
  completedAt: at ?? DateTime(2026, 10, 11, 10),
  metrics: const StageAttemptMetrics(
    completed: true,
    movesUsed: 3,
    meaningfulSubmissionCount: 1,
    firstMeaningfulSubmissionCorrect: true,
    highestMathHintTierUsed: 0,
    usedDirectPathHint: true,
    usedGuidedCompletion: false,
  ),
);

void main() {
  test(
    'regional milestone completion unlocks its exact garden catalog node',
    () async {
      final source = initialCampaign.regions.first.chapters.first.stages[1];
      final plan = source.learningPlan;
      // Local authored regression fixture, independent of board authoring.
      final milestone = StageDefinition(
        id: source.id,
        chapterId: source.chapterId,
        skillId: source.skillId,
        number: source.number,
        title: source.title,
        conceptLabel: source.conceptLabel,
        answerExpression: source.answerExpression,
        puzzleId: source.puzzleId,
        contentStatus: StageContentStatus.playable,
        mathDifficulty: source.mathDifficulty,
        matchDifficulty: source.matchDifficulty,
        boardMechanicPlan: source.boardMechanicPlan,
        boardVariants: verticalSliceStage.boardVariants,
        moveBudget: source.moveBudget,
        starRules: source.starRules,
        assistRules: source.assistRules,
        learningPlan: StageLearningPlan(
          status: LearningPlanStatus.authored,
          primarySkillId: plan.primarySkillId,
          prerequisiteSkillIds: plan.prerequisiteSkillIds,
          reinforcedSkillIds: plan.reinforcedSkillIds,
          variantId: plan.variantId,
          variantProfile: plan.variantProfile,
          role: plan.role,
          objective: plan.objective,
          nextStageId: plan.nextStageId,
          additionalUnlockStageIds: plan.additionalUnlockStageIds,
        ),
        variantProfile: source.variantProfile,
        recurrencePlan: source.recurrencePlan,
        seed: source.seed,
        startingTokenIds: source.startingTokenIds,
        buriedTokenIds: source.buriedTokenIds,
        decoyTokenIds: source.decoyTokenIds,
      );
      final repository = ProgressRepository(
        MemoryKeyValueSaveStore(),
        initialFactory: () => SaveEnvelopeV1(unlockedStageIds: [milestone.id]),
      );
      final receipt = await StageCompletionService(repository).complete(
        StageAttemptResult(
          attemptId: 'regional-milestone',
          stage: milestone,
          metrics: attempt('metrics').metrics,
          completedAt: DateTime(2026, 10, 11),
        ),
      );
      final expectedNode = gardenDefinitions.first.restorationNodes.singleWhere(
        (node) => node.requiredStageId == milestone.id,
      );
      expect(receipt.unlockedRestorationNodeIds, [expectedNode.id]);
      expect(expectedNode.id, 'r01-c01-garden-02');
      final daily = const DailyRouteService().build(
        await repository.load(),
        initialCampaign,
      );
      expect(daily.pendingRestorationNodeId, expectedNode.id);
      final replay = await StageCompletionService(repository).complete(
        StageAttemptResult(
          attemptId: 'regional-milestone-replay',
          stage: milestone,
          metrics: attempt('metrics').metrics,
          completedAt: DateTime(2026, 10, 11),
        ),
      );
      expect(replay.unlockedRestorationNodeIds, isEmpty);
    },
  );

  test('not-yet-due review cannot change rewards or progress', () async {
    final repository = ProgressRepository(MemoryKeyValueSaveStore());
    final service = StageCompletionService(repository);
    final first = attempt('first-review-source');
    await service.complete(first);
    final before = await repository.load();
    final ticket =
        before.skillProgress.values.single.pendingReviewTickets.single;
    await expectLater(
      service.complete(
        StageAttemptResult(
          attemptId: 'early-review',
          stage: verticalSliceStage,
          metrics: first.metrics,
          completedAt: first.completedAt,
          reviewTicketId: ticket.id,
        ),
      ),
      throwsStateError,
    );
    final after = await repository.load();
    expect(after.generation, before.generation);
    expect(after.rewardLedger.containsKey('early-review'), isFalse);
  });

  test('planned stages cannot produce a completion ledger entry', () async {
    final repository = ProgressRepository(MemoryKeyValueSaveStore());
    await expectLater(
      StageCompletionService(repository).complete(
        StageAttemptResult(
          attemptId: 'planned-attempt',
          stage: initialCampaign.stages.firstWhere(
            (stage) => !stage.isPlayable,
          ),
          metrics: attempt('metrics-source').metrics,
          completedAt: DateTime(2026, 10, 11),
        ),
      ),
      throwsStateError,
    );
    expect((await repository.load()).rewardLedger, isEmpty);
  });

  test(
    'due ticket remains pending without an independent playable variant',
    () async {
      final repository = ProgressRepository(MemoryKeyValueSaveStore());
      await StageCompletionService(
        repository,
      ).complete(attempt('review-source'));
      await repository.update(
        (s) => s.copyWith(
          completedStageIds: {
            ...s.completedStageIds,
            'unknown-preserved-stage',
          },
        ),
      );
      final snapshot = await repository.load();
      final route = const DailyRouteService().build(
        snapshot,
        prototypeCampaign,
      );
      expect(route.reviewTicket, isNotNull);
      expect(route.reviewStage, isNull);
      expect(
        snapshot.skillProgress.values.single.pendingReviewTickets,
        hasLength(1),
      );
    },
  );

  test('initial save unlocks prototype and first regional stage', () async {
    final initial = await ProgressRepository(MemoryKeyValueSaveStore()).load();
    expect(initial.generation, 0);
    expect(
      initial.unlockedStageIds,
      containsAll(['prototype-bundle-add', 'r01-c01-s01']),
    );
  });

  test('parallel transforms serialize and preserve every update', () async {
    final repository = ProgressRepository(MemoryKeyValueSaveStore());
    await Future.wait(
      List.generate(
        20,
        (i) => repository.update(
          (s) => s.copyWith(viewedStoryIds: {...s.viewedStoryIds, 'story-$i'}),
        ),
      ),
    );
    final snapshot = await repository.load();
    expect(snapshot.viewedStoryIds.length, 20);
    expect(snapshot.generation, 20);
  });

  test('stale snapshots cannot overwrite concurrent changes', () async {
    final repository = ProgressRepository(MemoryKeyValueSaveStore());
    final initial = await repository.load();
    await repository.update((s) => s.copyWith(viewedStoryIds: ['new-story']));
    await expectLater(repository.save(initial), throwsStateError);
    expect((await repository.load()).viewedStoryIds, ['new-story']);
  });

  test(
    'failed pointer preserves committed state despite newer orphan slot',
    () async {
      final store = FailingStore();
      final repository = ProgressRepository(store);
      await repository.update((s) => s.copyWith(viewedStoryIds: ['committed']));
      store.failingWriteKey = ProgressRepository.pointerKey;
      await expectLater(
        repository.update((s) => s.copyWith(viewedStoryIds: ['orphan'])),
        throwsStateError,
      );
      store.failingWriteKey = null;
      final recovered = await ProgressRepository(store).load();
      expect(recovered.viewedStoryIds, ['committed']);
      expect(recovered.generation, 1);
    },
  );

  test('first transaction failure recovers initial checkpoint', () async {
    final store = FailingStore()
      ..failingWriteKey = ProgressRepository.pointerKey;
    await expectLater(
      ProgressRepository(
        store,
      ).update((s) => s.copyWith(viewedStoryIds: ['orphan'])),
      throwsStateError,
    );
    store.failingWriteKey = null;
    final recovered = await ProgressRepository(store).load();
    expect(recovered.generation, 0);
    expect(recovered.viewedStoryIds, isEmpty);
  });

  test(
    'inactive slot must pass exact readback before pointer changes',
    () async {
      final store = FailingStore();
      final repository = ProgressRepository(store);
      await repository.update((s) => s.copyWith(viewedStoryIds: ['committed']));
      final pointer = store.values[ProgressRepository.pointerKey];
      store.corruptSlotReadback = true;
      await expectLater(
        repository.update((s) => s.copyWith(viewedStoryIds: ['unverified'])),
        throwsA(isA<SaveWriteException>()),
      );
      store.corruptSlotReadback = false;
      expect(store.values[ProgressRepository.pointerKey], pointer);
      expect((await ProgressRepository(store).load()).viewedStoryIds, [
        'committed',
      ]);
    },
  );

  test('corrupt active slot falls back to previous committed slot', () async {
    final store = MemoryKeyValueSaveStore();
    final repository = ProgressRepository(store);
    await repository.update((s) => s.copyWith(viewedStoryIds: ['first']));
    await repository.update((s) => s.copyWith(viewedStoryIds: ['second']));
    final activeKey = store.values[ProgressRepository.pointerKey] == 'a'
        ? ProgressRepository.slotAKey
        : ProgressRepository.slotBKey;
    store.values[activeKey] = 'broken JSON';
    final recovered = await ProgressRepository(store).load();
    expect(recovered.generation, 1);
    expect(recovered.viewedStoryIds, ['first']);
  });

  test('both corrupt slots report failure without resetting data', () async {
    final store = MemoryKeyValueSaveStore({
      ProgressRepository.slotAKey: 'broken',
    });
    await expectLater(
      ProgressRepository(store).load(),
      throwsA(isA<CorruptSaveException>()),
    );
    expect(store.values[ProgressRepository.slotAKey], 'broken');
  });

  test(
    'future schema blocks load and mutation even with valid older slot',
    () async {
      final store = MemoryKeyValueSaveStore({
        ProgressRepository.slotAKey: jsonEncode(
          SaveEnvelopeV1.initial().toJson(),
        ),
        ProgressRepository.slotBKey: jsonEncode({'schemaVersion': 2}),
        ProgressRepository.pointerKey: 'a',
      });
      final before = {...store.values};
      final repository = ProgressRepository(store);
      await expectLater(
        repository.load(),
        throwsA(isA<FutureSaveVersionException>()),
      );
      await expectLater(
        repository.update((s) => s.copyWith(viewedStoryIds: ['change'])),
        throwsA(isA<FutureSaveVersionException>()),
      );
      expect(store.values, before);
    },
  );

  test('semantic evidence and review ticket survive JSON round trip', () async {
    final repository = ProgressRepository(MemoryKeyValueSaveStore());
    await StageCompletionService(repository).complete(attempt('semantic-save'));
    final source = await repository.load();
    final decoded = SaveEnvelopeV1.fromJson(
      jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>,
    );
    final skillId = verticalSliceStage.learningPlan.primarySkillId;
    final ticket = decoded.skillProgress[skillId]!.pendingReviewTickets.single;
    expect(
      ticket.sourceVariantProfile.meaningfulFingerprint,
      verticalSliceStage.learningPlan.semanticFingerprint,
    );
    expect(ticket.sourceVariantProfile.problemSeed, verticalSliceStage.seed);
    expect(ticket.reason, ReviewReason.supportNeeded);
    expect(decoded.masteryStates[skillId], SkillMasteryState.reviewDue);
    expect(decoded.skillProgress[skillId]!.independentVariantProfiles, isEmpty);
    expect(decoded.rewardLedger['semantic-save']!.stars, 1);
  });

  test(
    'duplicate completion is idempotent under concurrency and restart',
    () async {
      final store = MemoryKeyValueSaveStore();
      final repository = ProgressRepository(store);
      final service = StageCompletionService(repository);
      final receipts = await Future.wait([
        service.complete(attempt('same')),
        service.complete(attempt('same')),
      ]);
      expect(receipts.every((receipt) => receipt.firstCompletion), isTrue);
      final snapshot = await repository.load();
      expect(snapshot.generation, 1);
      expect(snapshot.dailyActions['2026-10-11'], 1);
      expect(snapshot.rewardLedger.length, 1);
      expect(snapshot.rewardLedger['same']!.unlockedRestorationNodeIds, [
        'r01-demo-meadow',
      ]);
      await StageCompletionService(
        ProgressRepository(store),
      ).complete(attempt('same'));
      expect((await ProgressRepository(store).load()).generation, 1);
    },
  );

  test(
    'replays keep highest stars and do not unlock duplicate restoration',
    () async {
      final repository = ProgressRepository(MemoryKeyValueSaveStore());
      final service = StageCompletionService(repository);
      await service.complete(attempt('first'));
      final replay = await service.complete(attempt('second'));
      expect(replay.firstCompletion, isFalse);
      expect(replay.unlockedRestorationNodeIds, isEmpty);
      final saved = await repository.load();
      expect(saved.completedStageIds.length, 1);
      expect(saved.dailyActions['2026-10-11'], 2);
      expect(saved.restoredNodeIds, isEmpty);
    },
  );

  test(
    'session is deep immutable and restored exactly after restart',
    () async {
      final store = MemoryKeyValueSaveStore();
      final repository = ProgressRepository(store);
      final source = <String, dynamic>{
        'board': [
          [1, 2],
        ],
        'moves': 3,
        'draft': ['4', '×'],
      };
      await repository.update((s) => s.copyWith(activeSession: source));
      (source['draft'] as List).add('3');
      final session = (await ProgressRepository(store).load()).activeSession!;
      expect(session['draft'], ['4', '×']);
      expect(() => (session['draft'] as List).add('3'), throwsUnsupportedError);
      await StageCompletionService(
        repository,
      ).complete(attempt('clear-session'));
      expect((await repository.load()).activeSession, isNull);
    },
  );

  test('unknown catalog IDs persist and invalid runtime JSON is rejected', () {
    final snapshot = SaveEnvelopeV1(
      completedStageIds: ['future-stage'],
      unlockedCharacterIds: ['future-character'],
    );
    final decoded = SaveEnvelopeV1.fromJson(snapshot.toJson());
    expect(decoded.completedStageIds, ['future-stage']);
    expect(decoded.unlockedCharacterIds, ['future-character']);
    final invalid = snapshot.toJson()..['bestStars'] = {'future-stage': 4};
    expect(() => SaveEnvelopeV1.fromJson(invalid), throwsFormatException);
    expect(
      () => SaveEnvelopeV1(dailyActions: {'2026-02-30': 1}),
      throwsFormatException,
    );
  });

  test(
    'daily route only offers unlocked playable stages and calendar records',
    () async {
      final repository = ProgressRepository(MemoryKeyValueSaveStore());
      await StageCompletionService(repository).complete(attempt('daily'));
      await repository.update(
        (s) => s.copyWith(
          dailyActions: {'2026-10-11': 1, '2026-10-09': 3, '2026-10-04': 2},
        ),
      );
      final saved = await repository.load();
      final route = const DailyRouteService().build(
        saved,
        prototypeCampaign,
        now: DateTime(2026, 10, 11),
      );
      expect(route.explorationStage?.id, 'prototype-bundle-add');
      expect(route.pendingRestorationNodeId, 'r01-demo-meadow');
      expect(route.todayActions, 1);
      expect(route.activeDaysInLastWeek, 2);
      expect(route.reviewTicket, isNull);
      final regional = const DailyRouteService().build(saved, initialCampaign);
      expect(regional.explorationStage?.id, 'r01-c01-s01');
      await repository.update(
        (s) => s.copyWith(
          restoredNodeIds: ['r01-demo-meadow'],
          decorationChoices: {'r01-demo-meadow': 'blue'},
        ),
      );
      final decorated = await repository.load();
      expect(decorated.bestStars, saved.bestStars);
      expect(
        const DailyRouteService()
            .build(decorated, prototypeCampaign)
            .pendingRestorationNodeId,
        isNull,
      );
    },
  );
}
