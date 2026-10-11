import '../../campaign/domain/campaign_models.dart';
import '../../campaign/domain/learning_models.dart';
import '../../campaign/domain/learning_progression_engine.dart';
import '../../garden/data/garden_catalog.dart';
import '../data/progress_repository.dart';
import 'campaign_access_policy.dart';
import 'progress_models.dart';

class StageCompletionService {
  StageCompletionService(
    this.repository, {
    this.learningEngine = const LearningProgressionEngine(),
    this.campaign,
  });
  final ProgressRepository repository;
  final LearningProgressionEngine learningEngine;

  /// The runtime catalog filters recommendations; legacy callers stay valid.
  final CampaignDefinition? campaign;

  Future<CompletionReceipt> complete(StageAttemptResult result) async {
    CompletionReceipt? receipt;
    await repository.update((current) {
      final existing = current.rewardLedger[result.attemptId];
      if (existing != null) {
        if (existing.stageId != result.stage.id)
          throw StateError('Attempt ID was already used for another stage.');
        receipt = existing;
        return current;
      }
      final stage = result.stage;
      if (!stage.isPlayable ||
          stage.learningPlan.status != LearningPlanStatus.authored) {
        throw StateError(
          'Only playable stages with authored learning plans can complete.',
        );
      }
      if (!current.unlockedStageIds.contains(stage.id))
        throw StateError('The stage is locked.');
      if (campaign != null &&
          !const CampaignAccessPolicy().canEnterStage(
            stage,
            campaign!,
            current.completedStageIds,
          )) {
        throw StateError('Complete the earlier garden before this project.');
      }
      final recurrence = stage.recurrencePlan;
      if (recurrence?.isSpiral == true &&
          !current.completedStageIds.contains(recurrence!.sourceStageId)) {
        throw StateError('Complete the source stage before its review branch.');
      }
      if (!result.metrics.completed)
        throw StateError('Incomplete attempts cannot grant rewards.');
      if (result.metrics.meaningfulSubmissionCount < 1)
        throw StateError('Completion requires a meaningful submission.');
      final firstCompletion = !current.completedStageIds.contains(stage.id);
      final completedIds = {...current.completedStageIds, stage.id};
      final plan = stage.learningPlan;
      if (result.reviewTicketId != null) {
        final matching = current
            .skillProgress[plan.primarySkillId]
            ?.pendingReviewTickets
            .where((ticket) => ticket.id == result.reviewTicketId)
            .toList();
        if (matching == null ||
            matching.length != 1 ||
            matching.single.dueAfterCompletedStageCount >
                current.completedStageIds.length) {
          throw StateError(
            'The requested review ticket is missing or not due.',
          );
        }
      }
      final forced = stage.assistRules.tutorialMode == StageTutorialMode.forced;
      final m = result.metrics;
      // Forced tutorial guidance is not independent mathematical evidence.
      final evidenceMetrics = forced
          ? StageAttemptMetrics(
              completed: m.completed,
              movesUsed: m.movesUsed,
              meaningfulSubmissionCount: m.meaningfulSubmissionCount,
              firstMeaningfulSubmissionCorrect:
                  m.firstMeaningfulSubmissionCorrect,
              highestMathHintTierUsed: m.highestMathHintTierUsed,
              usedDirectPathHint: m.usedDirectPathHint,
              usedGuidedCompletion: true,
            )
          : m;
      final decision = learningEngine.decide(
        plan: plan,
        evidence: LearningAttemptEvidence(
          metrics: evidenceMetrics,
          variantId: plan.variantId,
          variantProfile: plan.variantProfile,
          reviewTicketId: result.reviewTicketId,
          misconceptionIds: result.misconceptionIds,
        ),
        completedStageCountAfterAttempt: completedIds.length,
        progress:
            current.skillProgress[plan.primarySkillId] ??
            SkillProgressSnapshot(skillId: plan.primarySkillId),
      );
      final starResult = stage.starRules.evaluate(
        evidenceMetrics,
        stage.moveBudget,
      );
      final mathStar =
          starResult.mathMastery && !evidenceMetrics.usedGuidedCompletion;
      final stars = 1 + (mathStar ? 1 : 0) + (starResult.exploration ? 1 : 0);
      final nodes = <String>[];
      if (firstCompletion) {
        if (stage.id == 'prototype-bundle-add')
          nodes.add('r01-demo-meadow');
        else if (const [2, 4, 7, 10].contains(stage.number))
          nodes.add(
            '${stage.chapterId}-garden-${stage.number.toString().padLeft(2, '0')}',
          );
      }
      final unlockedIds = {
        ...current.unlockedStageIds,
        ...decision.unlockedStageIds.where(
          (id) => _canUnlock(id, completedIds),
        ),
      };
      // Review branches open from their real authored source, independently of
      // the main route and without treating an early branch as delayed mastery.
      for (final candidate in campaign?.stages ?? <StageDefinition>[]) {
        final source = candidate.recurrencePlan?.sourceStageId;
        if (candidate.isPlayable &&
            candidate.learningPlan.status == LearningPlanStatus.authored &&
            candidate.chapterId.endsWith('-c04') &&
            candidate.recurrencePlan?.isSpiral == true &&
            source != null &&
            completedIds.contains(source)) {
          unlockedIds.add(candidate.id);
        }
        // A review's last numbered stage may have been played before its other
        // source-linked entries. Reconsider its successor when the final gate
        // becomes satisfied, without requiring a duplicate replay of S10.
        if (completedIds.contains(candidate.id)) {
          unlockedIds.addAll(
            candidate.learningPlan.unlockStageIds.where(
              (id) => _canUnlock(id, completedIds),
            ),
          );
        }
      }
      final nextStageId = campaign == null
          ? decision.unlockedStageId
          : const CampaignAccessPolicy()
                .nextUncompletedStage(campaign!, unlockedIds, completedIds)
                ?.id;
      final characters = {...current.unlockedCharacterIds};
      if (stage.id == 'prototype-bundle-add')
        characters.addAll(const ['CHAR_D', 'CHAR_J']);
      for (final story in r1CharacterStories) {
        if (story.requiredStageId == null ||
            completedIds.contains(story.requiredStageId)) {
          characters.add(story.characterId);
        }
      }
      receipt = CompletionReceipt(
        attemptId: result.attemptId,
        stageId: stage.id,
        stars: stars,
        firstCompletion: firstCompletion,
        supportReviewNeeded: decision.supportReviewNeeded,
        unlockedRestorationNodeIds: nodes,
        nextStageId: nextStageId,
        unlockedCharacterIds: characters.difference(
          current.unlockedCharacterIds,
        ),
      );
      final day = localDateKey(result.completedAt);
      final bestStars = {...current.bestStars};
      if (stars > (bestStars[stage.id] ?? 0)) bestStars[stage.id] = stars;
      return current.copyWith(
        completedStageIds: completedIds,
        unlockedStageIds: unlockedIds,
        bestStars: bestStars,
        unlockedCharacterIds: characters,
        skillProgress: {
          ...current.skillProgress,
          plan.primarySkillId: decision.updatedProgress,
        },
        masteryStates: {
          ...current.masteryStates,
          plan.primarySkillId: decision.masteryState,
        },
        rewardLedger: {...current.rewardLedger, result.attemptId: receipt!},
        dailyActions: {
          ...current.dailyActions,
          day: (current.dailyActions[day] ?? 0) + 1,
        },
        dailyReviewActions: {
          ...current.dailyReviewActions,
          if (result.isDailyReview ||
              result.reviewTicketId != null ||
              stage.recurrencePlan?.isSpiral == true)
            day: (current.dailyReviewActions[day] ?? 0) + 1,
        },
        stageLastPlayedDates: {...current.stageLastPlayedDates, stage.id: day},
        clearActiveSession: true,
      );
    });
    return receipt!;
  }

  bool _canUnlock(String stageId, Set<String> completedIds) {
    final catalog = campaign;
    if (catalog == null) return true;
    final target = catalog.stageById(stageId);
    // Future-region unlock metadata survives an update, but planned stages are
    // excluded from every runtime recommendation and completion path.
    if (target == null || !target.isPlayable) return true;
    return const CampaignAccessPolicy().canEnterStage(
      target,
      catalog,
      completedIds,
    );
  }
}
