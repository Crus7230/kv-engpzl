import '../../campaign/domain/campaign_models.dart';
import '../data/progress_repository.dart';
import 'campaign_access_policy.dart';
import 'progress_models.dart';

/// Additive catalog reconciliation, not a save-format migration or reset.
/// A successor filtered out while planned becomes available after authoring.
/// No invented completion, learning evidence, reward, date, or session change.
class CampaignContentUpdateService {
  const CampaignContentUpdateService(this.repository, this.campaign);
  final ProgressRepository repository;
  final CampaignDefinition campaign;

  Future<SaveEnvelopeV1> reconcileUnlocks() => repository.update((save) {
    final unlocked = {...save.unlockedStageIds};
    for (final stage in campaign.stages) {
      if (save.completedStageIds.contains(stage.id)) {
        for (final id in stage.learningPlan.unlockStageIds) {
          final next = campaign.stageById(id);
          if (next != null &&
              const CampaignAccessPolicy().canEnterStage(
                next,
                campaign,
                save.completedStageIds,
              ))
            unlocked.add(id);
        }
      }
      final source = stage.recurrencePlan?.sourceStageId;
      if (stage.chapterId.endsWith('-c04') &&
          source != null &&
          save.completedStageIds.contains(source) &&
          const CampaignAccessPolicy().canEnterStage(
            stage,
            campaign,
            save.completedStageIds,
          ))
        unlocked.add(stage.id);
    }
    return unlocked.length == save.unlockedStageIds.length
        ? save
        : save.copyWith(unlockedStageIds: unlocked);
  });
}
