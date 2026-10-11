import 'campaign_models.dart';

/// Minimal, storage-agnostic campaign progress used at catalog boundaries.
///
/// Unknown IDs are preserved so a migration never silently deletes user data.
class CampaignProgressSnapshot {
  CampaignProgressSnapshot({
    required this.campaignVersion,
    Iterable<String> completedStageIds = const [],
    Iterable<String> unlockedStageIds = const [],
  }) : completedStageIds = Set.unmodifiable(completedStageIds),
       unlockedStageIds = Set.unmodifiable(unlockedStageIds);

  final int campaignVersion;
  final Set<String> completedStageIds;
  final Set<String> unlockedStageIds;
}

/// Rebuilds unlock consequences after a campaign graph changes.
///
/// Version 4 added C04-C06 and made C03 S10 a branch gate. Replaying every
/// completed stage's declared unlocks backfills those branches for existing
/// version-3 saves without requiring the player to complete C03 again.
class CampaignProgressMigrator {
  const CampaignProgressMigrator();

  CampaignProgressSnapshot migrate({
    required CampaignProgressSnapshot progress,
    required CampaignDefinition campaign,
  }) {
    if (progress.campaignVersion > campaign.version) {
      throw StateError(
        'Cannot migrate campaign progress from newer version '
        '${progress.campaignVersion} to ${campaign.version}.',
      );
    }

    final unlockedStageIds = <String>{
      ...progress.unlockedStageIds,
      ...progress.completedStageIds,
    };
    final firstStage = campaign.stages.firstOrNull;
    if (firstStage != null) {
      unlockedStageIds.add(firstStage.id);
    }
    for (final completedStageId in progress.completedStageIds) {
      final completedStage = campaign.stageById(completedStageId);
      if (completedStage == null) {
        continue;
      }
      unlockedStageIds.addAll(completedStage.learningPlan.unlockStageIds);
    }

    return CampaignProgressSnapshot(
      campaignVersion: campaign.version,
      completedStageIds: progress.completedStageIds,
      unlockedStageIds: unlockedStageIds,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
