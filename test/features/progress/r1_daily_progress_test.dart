import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/campaign/domain/campaign_models.dart';
import 'package:kvm/features/campaign/domain/learning_models.dart';
import 'package:kvm/features/campaign/domain/stage_recurrence_models.dart';
import 'package:kvm/features/progress/data/progress_repository.dart';
import 'package:kvm/features/progress/domain/daily_route_service.dart';
import 'package:kvm/features/progress/domain/progress_models.dart';
import 'package:kvm/features/progress/domain/stage_completion_service.dart';

StageDefinition stage(String id) => initialCampaign.stageById(id)!;

StageAttemptResult success(
  String attemptId,
  StageDefinition definition, {
  DateTime? at,
  String? reviewTicketId,
  bool isDailyReview = false,
  bool guided = false,
}) => StageAttemptResult(
  attemptId: attemptId,
  stage: definition,
  completedAt: at ?? DateTime(2026, 10, 11, 10),
  reviewTicketId: reviewTicketId,
  isDailyReview: isDailyReview,
  metrics: StageAttemptMetrics(
    completed: true,
    movesUsed: definition.moveBudget.referenceMoves,
    meaningfulSubmissionCount: 1,
    firstMeaningfulSubmissionCorrect: true,
    highestMathHintTierUsed: guided ? 3 : 0,
    usedDirectPathHint: false,
    usedGuidedCompletion: guided,
  ),
);

List<StageDefinition> get coreStages => initialCampaign.regions.first.stages
    .where((definition) => definition.isPlayable && definition.number <= 10)
    .where(
      (definition) =>
          definition.chapterId == 'r01-c01' ||
          definition.chapterId == 'r01-c02' ||
          definition.chapterId == 'r01-c03',
    )
    .toList();

ReviewTicket dueTicket(
  String id,
  LearningVariantProfile profile, {
  int dueAfter = 2,
}) => ReviewTicket(
  id: id,
  skillId: profile.primarySkillId,
  sourceVariantId: profile.stageId,
  sourceVariantProfile: profile,
  policyIndex: 0,
  stageOffset: 2,
  dueAfterCompletedStageCount: dueAfter,
  reason: ReviewReason.spacedPractice,
);

void main() {
  test('R1 has 30 authored core stages and 10 source-linked early reviews', () {
    expect(coreStages, hasLength(30));
    final reviews = initialCampaign.regions.first.stages
        .where((definition) => definition.chapterId == 'r01-c04')
        .toList();
    expect(reviews, hasLength(10));
    expect(reviews.every((definition) => definition.isPlayable), isTrue);
    for (final review in reviews) {
      final source = stage(review.recurrencePlan!.sourceStageId);
      expect(source.isPlayable, isTrue);
      expect(
        source.learningPlan.variantProfile.isIndependentVariationFrom(
          review.learningPlan.variantProfile,
        ),
        isTrue,
      );
    }
  });

  test(
    'daily practice starts on the next calendar day, not after 24 hours',
    () async {
      final repository = ProgressRepository(MemoryKeyValueSaveStore());
      final service = StageCompletionService(
        repository,
        campaign: initialCampaign,
      );
      final first = stage('r01-c01-s01');
      await service.complete(
        success('late-night', first, at: DateTime(2026, 10, 11, 23, 59)),
      );
      final snapshot = await repository.load();
      final sameDay = const DailyRouteService().build(
        snapshot,
        initialCampaign,
        now: DateTime(2026, 10, 11, 23, 59),
      );
      expect(sameDay.reviewKind, DailyReviewKind.none);
      final tomorrow = const DailyRouteService().build(
        snapshot,
        initialCampaign,
        now: DateTime(2026, 10, 12, 0, 1),
      );
      expect(tomorrow.reviewKind, DailyReviewKind.dailyPractice);
      expect(tomorrow.reviewStage!.id, first.id);
      expect(tomorrow.reviewTicket, isNull);
      expect(tomorrow.explorationStage!.id, 'r01-c01-s02');
    },
  );

  test(
    'one daily practice is recorded without consuming an early ticket',
    () async {
      final repository = ProgressRepository(MemoryKeyValueSaveStore());
      final service = StageCompletionService(
        repository,
        campaign: initialCampaign,
      );
      final first = stage('r01-c01-s01');
      await service.complete(success('day-one', first));
      final before = await repository.load();
      final originalTicket = before
          .skillProgress[first.learningPlan.primarySkillId]!
          .pendingReviewTickets
          .single;
      await service.complete(
        success(
          'calendar-review',
          first,
          at: DateTime(2026, 10, 12),
          isDailyReview: true,
        ),
      );
      final after = await repository.load();
      expect(after.dailyReviewActions['2026-10-12'], 1);
      expect(after.completedStageIds, before.completedStageIds);
      final skill = after.skillProgress[first.learningPlan.primarySkillId]!;
      expect(skill.pendingReviewTickets.single.id, originalTicket.id);
      expect(skill.hasDelayedIndependentSuccess, isFalse);
      final route = const DailyRouteService().build(
        after,
        initialCampaign,
        now: DateTime(2026, 10, 12),
      );
      expect(route.reviewCompletedToday, isTrue);
      expect(route.reviewStage, isNull);
      // Daily recommendation is complete; ordinary free replay stays available.
      final replay = await service.complete(
        success('free-replay', first, at: DateTime(2026, 10, 12)),
      );
      expect(replay.firstCompletion, isFalse);
      expect((await repository.load()).dailyReviewActions['2026-10-12'], 1);
    },
  );

  test(
    'an unmatched older ticket does not suppress a later eligible review',
    () {
      final source = stage('r01-c01-s06');
      final review = stage('r01-c04-s01');
      final missingProfile = LearningVariantProfile(
        stageId: 'old-unavailable-source',
        primarySkillId: 'unavailable.skill',
        relationSchemaId: 'old-relation',
        answerAstShapeId: 'add',
        operandBandId: 'single-digit',
        unknownPositionId: 'result',
        contextFamilyId: 'old-context',
        representationId: 'word-problem',
      );
      final missing = dueTicket('a-unavailable', missingProfile);
      final eligible = dueTicket(
        'b-eligible',
        source.learningPlan.variantProfile,
      );
      final snapshot = SaveEnvelopeV1(
        completedStageIds: [source.id, 'other-completion'],
        unlockedStageIds: [review.id],
        skillProgress: {
          missing.skillId: SkillProgressSnapshot(
            skillId: missing.skillId,
            pendingReviewTickets: [missing],
          ),
          eligible.skillId: SkillProgressSnapshot(
            skillId: eligible.skillId,
            pendingReviewTickets: [eligible],
          ),
        },
      );
      final route = const DailyRouteService().build(
        snapshot,
        initialCampaign,
        now: DateTime(2026, 10, 12),
      );
      expect(route.reviewKind, DailyReviewKind.dueReview);
      expect(route.reviewTicket!.id, eligible.id);
      expect(route.reviewStage!.id, review.id);
      expect(
        snapshot.skillProgress[missing.skillId]!.pendingReviewTickets.single.id,
        missing.id,
      );
    },
  );

  test(
    'source-linked review opens only when its original stage is completed',
    () async {
      final repository = ProgressRepository(MemoryKeyValueSaveStore());
      final service = StageCompletionService(
        repository,
        campaign: initialCampaign,
      );
      for (final definition in coreStages.take(5)) {
        await service.complete(success('source-${definition.id}', definition));
      }
      expect(
        (await repository.load()).unlockedStageIds,
        isNot(contains('r01-c04-s01')),
      );
      await service.complete(success('source-six', stage('r01-c01-s06')));
      final snapshot = await repository.load();
      expect(snapshot.unlockedStageIds, contains('r01-c04-s01'));
      expect(snapshot.unlockedStageIds, isNot(contains('r01-c04-s02')));
      final route = const DailyRouteService().build(
        snapshot,
        initialCampaign,
        now: DateTime(2026, 10, 12),
      );
      expect(route.reviewStage, isNotNull);
      expect(route.explorationStage!.id, 'r01-c01-s07');
    },
  );

  test(
    'stale or imported review unlock cannot bypass source completion',
    () async {
      final review = stage('r01-c04-s01');
      final repository = ProgressRepository(
        MemoryKeyValueSaveStore(),
        initialFactory: () => SaveEnvelopeV1(unlockedStageIds: [review.id]),
      );
      await expectLater(
        StageCompletionService(
          repository,
          campaign: initialCampaign,
        ).complete(success('unearned-review', review)),
        throwsStateError,
      );
      expect((await repository.load()).rewardLedger, isEmpty);
    },
  );

  test(
    'all 30 core and 30 review/workshop completions preserve progression',
    () async {
      final repository = ProgressRepository(MemoryKeyValueSaveStore());
      final service = StageCompletionService(
        repository,
        campaign: initialCampaign,
      );
      final restorationIds = <String>{};
      for (var index = 0; index < coreStages.length; index++) {
        final definition = coreStages[index];
        final receipt = await service.complete(
          success('core-$index', definition, guided: true),
        );
        restorationIds.addAll(receipt.unlockedRestorationNodeIds);
        expect(receipt.stars, greaterThanOrEqualTo(1));
        expect(
          receipt.nextStageId,
          index + 1 < coreStages.length
              ? coreStages[index + 1].id
              : 'r01-c04-s01',
        );
      }
      expect(
        restorationIds,
        containsAll([
          'r01-c01-garden-02',
          'r01-c01-garden-04',
          'r01-c01-garden-07',
          'r01-c01-garden-10',
          'r01-c02-garden-02',
          'r01-c02-garden-04',
        ]),
      );
      final reviews = initialCampaign.regions.first.stages.where(
        (definition) => definition.recurrencePlan?.isSpiral == true,
      );
      var reviewIndex = 0;
      for (final definition in reviews) {
        expect(
          (await repository.load()).unlockedStageIds,
          contains(definition.id),
        );
        final receipt = await service.complete(
          success(
            'review-${definition.id}',
            definition,
            at: DateTime(2026, 10, 12),
            isDailyReview: true,
          ),
        );
        restorationIds.addAll(receipt.unlockedRestorationNodeIds);
        reviewIndex++;
        expect(
          receipt.nextStageId,
          reviewIndex < 30 ? reviews.elementAt(reviewIndex).id : null,
        );
      }
      final finalSnapshot = await repository.load();
      expect(finalSnapshot.completedStageIds, hasLength(60));
      expect(finalSnapshot.rewardLedger, hasLength(60));
      expect(finalSnapshot.dailyReviewActions['2026-10-12'], 30);
      expect(restorationIds, hasLength(24));
      expect(finalSnapshot.restoredNodeIds, isEmpty);
      expect(
        const DailyRouteService()
            .build(finalSnapshot, initialCampaign, now: DateTime(2026, 10, 13))
            .explorationStage,
        isNull,
      );
    },
  );

  test(
    'daily review duplicate delivery stays idempotent after restart',
    () async {
      final store = MemoryKeyValueSaveStore();
      final repository = ProgressRepository(store);
      final service = StageCompletionService(
        repository,
        campaign: initialCampaign,
      );
      final first = stage('r01-c01-s01');
      await service.complete(success('original', first));
      final review = success(
        'daily-duplicate',
        first,
        at: DateTime(2026, 10, 12),
        isDailyReview: true,
      );
      await Future.wait([service.complete(review), service.complete(review)]);
      final reloadedRepository = ProgressRepository(store);
      await StageCompletionService(
        reloadedRepository,
        campaign: initialCampaign,
      ).complete(review);
      final saved = await reloadedRepository.load();
      expect(saved.dailyReviewActions['2026-10-12'], 1);
      expect(saved.dailyActions['2026-10-12'], 1);
      expect(saved.rewardLedger, hasLength(2));
    },
  );

  test(
    'optional daily fields inside the current epoch default safely',
    () async {
      final old =
          SaveEnvelopeV1.initial()
              .copyWith(
                completedStageIds: [
                  'prototype-bundle-add',
                  'unknown-preserved-stage',
                ],
                bestStars: {'prototype-bundle-add': 2},
                restoredNodeIds: ['r01-demo-meadow'],
                decorationChoices: {'r01-demo-meadow': 'herbs'},
                activeSession: {
                  'attemptId': 'old-attempt',
                  'stageId': 'prototype-bundle-add',
                },
              )
              .toJson()
            ..remove('dailyReviewActions')
            ..remove('stageLastPlayedDates');
      final store = MemoryKeyValueSaveStore({
        ProgressRepository.slotAKey: jsonEncode(old),
        ProgressRepository.pointerKey: 'a',
      });
      final repository = ProgressRepository(store);
      final migrated = await repository.load();
      expect(migrated.dailyReviewActions, isEmpty);
      expect(migrated.stageLastPlayedDates, isEmpty);
      expect(migrated.completedStageIds, contains('unknown-preserved-stage'));
      expect(migrated.decorationChoices['r01-demo-meadow'], 'herbs');
      expect(migrated.activeSession!['attemptId'], 'old-attempt');
      await repository.update(
        (snapshot) => snapshot.copyWith(
          stageLastPlayedDates: {'prototype-bundle-add': '2026-10-12'},
        ),
      );
      final reloaded = await ProgressRepository(store).load();
      expect(reloaded.bestStars['prototype-bundle-add'], 2);
      expect(reloaded.restoredNodeIds, contains('r01-demo-meadow'));
      expect(
        reloaded.stageLastPlayedDates['prototype-bundle-add'],
        '2026-10-12',
      );
    },
  );

  test(
    'daily calendar records reject malformed dates without erasing data',
    () {
      expect(
        () => SaveEnvelopeV1(dailyReviewActions: {'2026-02-30': 1}),
        throwsFormatException,
      );
      expect(
        () => SaveEnvelopeV1(stageLastPlayedDates: {'stage': 'tomorrow'}),
        throwsFormatException,
      );
    },
  );
}
