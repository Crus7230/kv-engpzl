import '../../campaign/domain/campaign_models.dart';
import '../../campaign/domain/learning_models.dart';

/// Completion gates are checked independently of persisted unlock IDs. This
/// keeps an old/imported unlock from entering a source-linked workshop early.
class CampaignAccessPolicy {
  const CampaignAccessPolicy();

  bool canEnterStage(
    StageDefinition stage,
    CampaignDefinition campaign,
    Set<String> completedStageIds, {
    bool usesLegacyBoardRules = false,
  }) {
    if (!stage.isPlayable ||
        stage.learningPlan.status != LearningPlanStatus.authored ||
        (!usesLegacyBoardRules &&
            !completedStageIds.contains(stage.id) &&
            !completedStageIds.containsAll(
              stage.boardMechanicPlan.prerequisiteStageIds,
            ))) {
      return false;
    }
    final familiarMathSource = stage.boardMechanicPlan.learningSourceStageId;
    if (!usesLegacyBoardRules &&
        !completedStageIds.contains(stage.id) &&
        familiarMathSource != null &&
        !completedStageIds.contains(familiarMathSource)) {
      return false;
    }
    final source = stage.recurrencePlan?.sourceStageId;
    if (stage.recurrencePlan?.isSpiral == true &&
        source != null &&
        !completedStageIds.contains(source)) {
      return false;
    }
    for (final region in campaign.regions) {
      for (final chapter in region.chapters) {
        if (chapter.id != stage.chapterId) continue;
        if (region.prerequisiteRegionId != null &&
            !completedStageIds.contains(
              campaign.regions
                  .singleWhere(
                    (prior) => prior.id == region.prerequisiteRegionId,
                  )
                  .accessGateStageId,
            )) {
          return false;
        }
        // C04 is intentionally an early, source-linked review branch. C05 and
        // C06 are sequential projects after the main route and earlier gardens.
        if (chapter.number >= 5) {
          return region.chapters
              .where((prior) => prior.number < chapter.number)
              .expand((prior) => prior.stages)
              .every((prior) => completedStageIds.contains(prior.id));
        }
        return true;
      }
    }
    // Development fixtures have no region and retain their existing contract.
    return true;
  }

  StageDefinition? nextUncompletedStage(
    CampaignDefinition campaign,
    Set<String> unlockedStageIds,
    Set<String> completedStageIds,
  ) {
    final available = campaign.stages.where(
      (stage) =>
          unlockedStageIds.contains(stage.id) &&
          !completedStageIds.contains(stage.id) &&
          canEnterStage(stage, campaign, completedStageIds),
    );
    // Continue the mathematical main route before optional review branches.
    // Once it ends, authored C04/C05/C06 remain genuine new exploration.
    for (final stage in available) {
      if (stage.recurrencePlan?.isSpiral != true) return stage;
    }
    for (final stage in available) {
      return stage;
    }
    return null;
  }
}
