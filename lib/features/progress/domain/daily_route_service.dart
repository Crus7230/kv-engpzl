import '../../campaign/domain/campaign_models.dart';
import '../../campaign/domain/learning_models.dart';
import 'campaign_access_policy.dart';
import 'progress_models.dart';

enum DailyReviewKind { none, dueReview, dailyPractice }

class DailyRouteRecommendations {
  const DailyRouteRecommendations({
    this.reviewTicket,
    this.reviewStage,
    this.explorationStage,
    this.pendingRestorationNodeId,
    this.reviewKind = DailyReviewKind.none,
    this.reviewCompletedToday = false,
    this.completedPlayableStageCount = 0,
    this.playableStageCount = 0,
    this.campaignCompleted = false,
    this.completedRegionIds = const {},
    required this.todayActions,
    required this.activeDaysInLastWeek,
  });
  final ReviewTicket? reviewTicket;

  /// Null until an authored, playable, unlocked independent variant exists.
  final StageDefinition? reviewStage;
  final DailyReviewKind reviewKind;
  final bool reviewCompletedToday;
  final StageDefinition? explorationStage;
  final String? pendingRestorationNodeId;
  final int todayActions;
  final int activeDaysInLastWeek;
  final int completedPlayableStageCount;
  final int playableStageCount;

  /// True only when every stage in the catalog is authored and completed.
  /// A smaller release region may be complete while future regions are planned.
  final bool campaignCompleted;
  final Set<String> completedRegionIds;
}

class DailyRouteService {
  const DailyRouteService();
  DailyRouteRecommendations build(
    SaveEnvelopeV1 snapshot,
    CampaignDefinition campaign, {
    DateTime? now,
  }) {
    final date = (now ?? DateTime.now()).toLocal();
    final available = campaign.stages
        .where(
          (stage) =>
              stage.isPlayable &&
              stage.learningPlan.status == LearningPlanStatus.authored &&
              snapshot.unlockedStageIds.contains(stage.id) &&
              const CampaignAccessPolicy().canEnterStage(
                stage,
                campaign,
                snapshot.completedStageIds,
              ),
        )
        .toList();
    final due =
        snapshot.skillProgress.values
            .expand((skill) => skill.pendingReviewTickets)
            .where(
              (ticket) =>
                  ticket.dueAfterCompletedStageCount <=
                  snapshot.completedStageIds.length,
            )
            .toList()
          ..sort((a, b) {
            final order = a.dueAfterCompletedStageCount.compareTo(
              b.dueAfterCompletedStageCount,
            );
            return order == 0 ? a.id.compareTo(b.id) : order;
          });
    final today = localDateKey(date);
    final reviewCompletedToday = (snapshot.dailyReviewActions[today] ?? 0) > 0;
    ReviewTicket? ticket;
    StageDefinition? reviewStage;
    var reviewKind = DailyReviewKind.none;
    if (!reviewCompletedToday) {
      // An older unserviceable ticket must not hide another due skill.
      for (final candidate in due) {
        // Prefer the authored source-linked review over unrelated main-route
        // variants of the same skill. Keep core variants as a valid fallback.
        for (final stage in [
          ...available.where((s) => s.recurrencePlan?.isSpiral == true),
          ...available.where((s) => s.recurrencePlan?.isSpiral != true),
        ]) {
          if (_isEligibleReview(stage, candidate, snapshot)) {
            ticket = candidate;
            reviewStage = stage;
            reviewKind = DailyReviewKind.dueReview;
            break;
          }
        }
        if (reviewStage != null) break;
      }
      if (reviewStage == null) {
        final practice =
            available.where((stage) {
              final isSpiral = stage.recurrencePlan?.isSpiral == true;
              if (!isSpiral && !snapshot.completedStageIds.contains(stage.id)) {
                return false;
              }
              final source = stage.recurrencePlan?.sourceStageId;
              final sourceId = source ?? stage.id;
              return snapshot.completedStageIds.contains(sourceId) &&
                  _wasPlayedBeforeToday(snapshot, sourceId, today) &&
                  _wasPlayedBeforeToday(snapshot, stage.id, today);
            }).toList()..sort((a, b) {
              // Prefer an authored spiral variation before exact replays, then
              // rotate the oldest encounter without streaks or punishments.
              final aReview = a.recurrencePlan?.isSpiral == true;
              final bReview = b.recurrencePlan?.isSpiral == true;
              if (aReview != bReview) return aReview ? -1 : 1;
              final order = (snapshot.stageLastPlayedDates[a.id] ?? '')
                  .compareTo(snapshot.stageLastPlayedDates[b.id] ?? '');
              return order == 0 ? a.id.compareTo(b.id) : order;
            });
        if (practice.isNotEmpty) {
          reviewStage = practice.first;
          reviewKind = DailyReviewKind.dailyPractice;
        }
      }
      // Keep the oldest unsatisfied ticket visible even when no stage is ready.
      ticket ??= reviewKind == DailyReviewKind.none && due.isNotEmpty
          ? due.first
          : null;
    }
    StageDefinition? exploration = const CampaignAccessPolicy()
        .nextUncompletedStage(
          campaign,
          snapshot.unlockedStageIds,
          snapshot.completedStageIds,
        );
    // Preserve the development fixture replay, but never present a completed
    // campaign stage as a new stage when this tranche has been exhausted.
    final prototypes = available.where(
      (stage) => stage.id == 'prototype-bundle-add',
    );
    exploration ??= prototypes.isEmpty ? null : prototypes.first;
    String? pending;
    for (final receipt in snapshot.rewardLedger.values) {
      for (final node in receipt.unlockedRestorationNodeIds) {
        if (!snapshot.restoredNodeIds.contains(node)) {
          pending = node;
          break;
        }
      }
      if (pending != null) break;
    }
    var activeDays = 0;
    for (var offset = 0; offset < 7; offset++) {
      // Calendar arithmetic, not 24-hour arithmetic, preserves DST dates.
      final day = DateTime(date.year, date.month, date.day - offset);
      if ((snapshot.dailyActions[localDateKey(day)] ?? 0) > 0) activeDays++;
    }
    final playableStages = campaign.stages
        .where((stage) => stage.isPlayable)
        .toList();
    final completedPlayable = playableStages
        .where((stage) => snapshot.completedStageIds.contains(stage.id))
        .length;
    final completedRegions = {
      for (final region in campaign.regions)
        if (region.stages.isNotEmpty &&
            region.stages.every(
              (stage) =>
                  stage.isPlayable &&
                  snapshot.completedStageIds.contains(stage.id),
            ))
          region.id,
    };
    return DailyRouteRecommendations(
      reviewTicket: ticket,
      reviewStage: reviewStage,
      reviewKind: reviewKind,
      reviewCompletedToday: reviewCompletedToday,
      explorationStage: exploration,
      pendingRestorationNodeId: pending,
      todayActions: snapshot.dailyActions[localDateKey(date)] ?? 0,
      activeDaysInLastWeek: activeDays,
      completedPlayableStageCount: completedPlayable,
      playableStageCount: playableStages.length,
      campaignCompleted:
          campaign.stages.isNotEmpty &&
          playableStages.length == campaign.stages.length &&
          completedPlayable == playableStages.length,
      completedRegionIds: Set.unmodifiable(completedRegions),
    );
  }

  bool _isEligibleReview(
    StageDefinition stage,
    ReviewTicket ticket,
    SaveEnvelopeV1 snapshot,
  ) {
    final sourceId = stage.recurrencePlan?.sourceStageId;
    return (sourceId == null ||
            snapshot.completedStageIds.contains(sourceId)) &&
        stage.learningPlan.primarySkillId == ticket.skillId &&
        ticket.sourceVariantProfile.isIndependentVariationFrom(
          stage.learningPlan.variantProfile,
        );
  }

  bool _wasPlayedBeforeToday(
    SaveEnvelopeV1 snapshot,
    String stageId,
    String today,
  ) {
    final lastPlayed = snapshot.stageLastPlayedDates[stageId];
    // A legacy v1 save has no calendar evidence; preserve its playable replays,
    // without inventing delayed mastery or consuming a pending review ticket.
    return lastPlayed == null || lastPlayed.compareTo(today) < 0;
  }
}
