import '../../progress/data/progress_repository.dart';
import '../../progress/domain/progress_models.dart';
import '../data/companion_catalog.dart';
import 'companion_models.dart';

bool isCompanionRecruitmentEligible(
  CompanionRecruitment recruitment,
  Set<String> completedStageIds,
) =>
    recruitment.available &&
    (recruitment.requiredStageId == null ||
        completedStageIds.contains(recruitment.requiredStageId));

/// Union only within the active expedition save. Replaying a milestone never
/// revokes the selected player or a previously rescued companion.
Set<String> companionOwnershipAfterProgress(
  Set<String> existingOwnedIds,
  Set<String> completedStageIds,
) => {
  ...existingOwnedIds,
  for (final recruitment in companionRecruitmentPlan)
    if (isCompanionRecruitmentEligible(recruitment, completedStageIds))
      recruitment.characterId,
};

/// Ownership and viewing are separate: owned companions can show an arrival scene
/// at its story milestone without granting a second reward or touching mastery.
CompanionRecruitment? nextUnviewedCompanionArrival(
  SaveEnvelopeV1 save, {
  String? regionId,
}) {
  for (final recruitment in companionRecruitmentPlan) {
    if ((regionId == null || recruitment.regionId == regionId) &&
        save.unlockedCharacterIds.contains(recruitment.characterId) &&
        save.playerCharacterId != recruitment.characterId &&
        isCompanionRecruitmentEligible(recruitment, save.completedStageIds) &&
        !save.viewedStoryIds.contains(recruitment.arrivalStoryId)) {
      return recruitment;
    }
  }
  return null;
}

class CompanionProgressService {
  const CompanionProgressService(this.repository);
  final ProgressRepository repository;

  /// Optional additive repair for an active save that missed a guaranteed unlock.
  /// This never mutates receipts, scores, restoration or learning state.
  Future<SaveEnvelopeV1> reconcileEligibility() => repository.update((save) {
    final ids = companionOwnershipAfterProgress(
      save.unlockedCharacterIds,
      save.completedStageIds,
    );
    if (ids.length == save.unlockedCharacterIds.length) return save;
    return save.copyWith(unlockedCharacterIds: ids);
  });

  Future<SaveEnvelopeV1> markArrivalViewed(String characterId) =>
      repository.update((save) {
        final recruitment = companionRecruitmentById(characterId);
        if (recruitment == null ||
            !save.unlockedCharacterIds.contains(characterId) ||
            save.playerCharacterId == characterId ||
            !isCompanionRecruitmentEligible(
              recruitment,
              save.completedStageIds,
            )) {
          throw StateError('This companion arrival is not yet available.');
        }
        if (save.viewedStoryIds.contains(recruitment.arrivalStoryId)) {
          return save;
        }
        return save.copyWith(
          viewedStoryIds: {...save.viewedStoryIds, recruitment.arrivalStoryId},
        );
      });
}
