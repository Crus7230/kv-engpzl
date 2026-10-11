import 'stage_attempt_metrics.dart';
import 'stage_recurrence_models.dart';

/// Pedagogical purpose of a stage within a learning sequence.
enum StageLearningRole {
  prerequisiteCheck,
  introduce,
  guidedPractice,
  independentPractice,
  nearTransfer,
  spacedReview,
  representationTransfer,
  farTransfer,
  cumulativeReview,
  checkpoint,
}

/// Authoring readiness of the learning plan, independent from board readiness.
enum LearningPlanStatus { planned, requiresRevision, authored }

/// Spaced-review offsets measured in completed stages, not wall-clock time.
class ReviewPolicy {
  const ReviewPolicy({
    this.defaultStageOffsets = const [2, 6, 15, 35, 75],
    this.supportNeededStageOffsets = const [1, 3, 7, 15, 35],
    this.requiredIndependentSuccesses = 2,
    this.minimumMasteryReviewOffset = 15,
  }) : assert(requiredIndependentSuccesses >= 1),
       assert(minimumMasteryReviewOffset >= 1);

  final List<int> defaultStageOffsets;
  final List<int> supportNeededStageOffsets;
  final int requiredIndependentSuccesses;

  /// A short +2 review is useful practice, but it is not delayed enough to
  /// count as retained learning. Mastery needs an independent review at this
  /// interval or later.
  final int minimumMasteryReviewOffset;

  List<int> offsetsFor({required bool supportNeeded}) =>
      supportNeeded ? supportNeededStageOffsets : defaultStageOffsets;
}

/// Learning metadata kept separate from physical board and puzzle readiness.
class StageLearningPlan {
  StageLearningPlan({
    required this.status,
    required this.primarySkillId,
    required Iterable<String> prerequisiteSkillIds,
    required Iterable<String> reinforcedSkillIds,
    required this.variantId,
    required this.variantProfile,
    required this.role,
    required this.objective,
    required this.nextStageId,
    Iterable<String> additionalUnlockStageIds = const [],
  }) : assert(primarySkillId != ''),
       assert(variantId != ''),
       assert(variantProfile.stageId == variantId),
       assert(variantProfile.primarySkillId == primarySkillId),
       assert(objective != ''),
       assert(nextStageId == null || nextStageId != ''),
       assert(additionalUnlockStageIds.every((stageId) => stageId != '')),
       prerequisiteSkillIds = Set.unmodifiable(prerequisiteSkillIds),
       reinforcedSkillIds = Set.unmodifiable(reinforcedSkillIds),
       additionalUnlockStageIds = Set.unmodifiable(additionalUnlockStageIds);

  final LearningPlanStatus status;
  final String primarySkillId;
  final Set<String> prerequisiteSkillIds;
  final Set<String> reinforcedSkillIds;
  final String variantId;

  /// Full semantic dimensions used to prove independent variation.
  final LearningVariantProfile variantProfile;
  String get semanticFingerprint => variantProfile.meaningfulFingerprint;
  final StageLearningRole role;
  final String objective;
  final String? nextStageId;

  /// Optional branch unlocks granted alongside [nextStageId].
  ///
  /// The regional campaign uses this at C03 S10: the recommended mastery route
  /// continues into C04 while the next region opens at the same time.
  final Set<String> additionalUnlockStageIds;

  Set<String> get unlockStageIds => Set.unmodifiable({
    if (nextStageId != null) nextStageId!,
    ...additionalUnlockStageIds,
  });

  Iterable<String> get practicedSkillIds sync* {
    yield primarySkillId;
    for (final skillId in reinforcedSkillIds) {
      if (skillId != primarySkillId) {
        yield skillId;
      }
    }
  }
}

enum SkillMasteryState {
  unseen,
  learning,
  provisionalMastery,
  reviewDue,
  mastered,
}

/// Attempt evidence used for math learning decisions.
///
/// Discovery path hints remain part of exploration scoring and deliberately do
/// not make a math attempt dependent.
class LearningAttemptEvidence {
  LearningAttemptEvidence({
    required this.metrics,
    required this.variantId,
    required this.variantProfile,
    this.reviewTicketId,
    Iterable<String> misconceptionIds = const [],
  }) : assert(variantId != ''),
       assert(variantProfile.stageId == variantId),
       assert(reviewTicketId == null || reviewTicketId != ''),
       misconceptionIds = Set.unmodifiable(misconceptionIds);

  final StageAttemptMetrics metrics;
  final String variantId;

  /// Semantic problem dimensions, excluding stage ID, seeds, and nouns.
  final LearningVariantProfile variantProfile;
  String get semanticFingerprint => variantProfile.meaningfulFingerprint;
  final String? reviewTicketId;
  final Set<String> misconceptionIds;

  bool get firstMeaningfulSubmissionFailed =>
      metrics.meaningfulSubmissionCount > 0 &&
      !metrics.firstMeaningfulSubmissionCorrect;

  bool get needsSupportReview =>
      metrics.completed &&
      (metrics.highestMathHintTierUsed > 1 ||
          metrics.usedGuidedCompletion ||
          misconceptionIds.isNotEmpty ||
          firstMeaningfulSubmissionFailed);

  bool get isIndependentSuccess =>
      metrics.completed &&
      metrics.meaningfulSubmissionCount > 0 &&
      metrics.firstMeaningfulSubmissionCorrect &&
      metrics.highestMathHintTierUsed == 0 &&
      !metrics.usedGuidedCompletion &&
      misconceptionIds.isEmpty;
}

enum ReviewReason { spacedPractice, supportNeeded }

class ReviewTicket {
  ReviewTicket({
    required this.id,
    required this.skillId,
    required this.sourceVariantId,
    required this.sourceVariantProfile,
    required this.policyIndex,
    required this.stageOffset,
    required this.dueAfterCompletedStageCount,
    required this.reason,
  }) : assert(id != ''),
       assert(skillId != ''),
       assert(sourceVariantId != ''),
       assert(sourceVariantProfile.stageId == sourceVariantId),
       assert(sourceVariantProfile.primarySkillId == skillId),
       assert(policyIndex >= 0),
       assert(stageOffset >= 1),
       assert(dueAfterCompletedStageCount >= stageOffset);

  final String id;
  final String skillId;
  final String sourceVariantId;
  final LearningVariantProfile sourceVariantProfile;
  String get sourceSemanticFingerprint =>
      sourceVariantProfile.meaningfulFingerprint;

  /// Zero-based position in the review policy selected by [reason].
  final int policyIndex;
  final int stageOffset;

  /// Absolute completed-stage count at which this review becomes due.
  final int dueAfterCompletedStageCount;
  final ReviewReason reason;
}

class SkillProgressSnapshot {
  SkillProgressSnapshot({
    required this.skillId,
    Iterable<LearningVariantProfile> independentVariantProfiles = const [],
    this.hasDelayedIndependentSuccess = false,
    this.hasTransferIndependentSuccess = false,
    Iterable<ReviewTicket> pendingReviewTickets = const [],
  }) : assert(skillId != ''),
       independentVariantProfiles = List.unmodifiable(
         independentVariantProfiles,
       ),
       pendingReviewTickets = List.unmodifiable(pendingReviewTickets);

  final String skillId;
  final List<LearningVariantProfile> independentVariantProfiles;
  Set<String> get independentSemanticFingerprints => Set.unmodifiable(
    independentVariantProfiles.map((profile) => profile.meaningfulFingerprint),
  );

  @Deprecated('Use independentSemanticFingerprints.')
  Set<String> get independentVariantIds => independentSemanticFingerprints;
  final bool hasDelayedIndependentSuccess;
  final bool hasTransferIndependentSuccess;
  final List<ReviewTicket> pendingReviewTickets;
}

enum NextAction { retryCurrentStage, continueToNextStage, completeLearningPath }

class LearningProgressDecision {
  LearningProgressDecision({
    required this.nextAction,
    required this.unlockedStageId,
    required this.masteryState,
    required this.updatedProgress,
    required this.supportReviewNeeded,
    Iterable<String> additionalUnlockedStageIds = const [],
    required Iterable<ReviewTicket> reviewTickets,
  }) : additionalUnlockedStageIds = Set.unmodifiable(
         additionalUnlockedStageIds,
       ),
       reviewTickets = List.unmodifiable(reviewTickets);

  final NextAction nextAction;
  final String? unlockedStageId;
  final Set<String> additionalUnlockedStageIds;
  final SkillMasteryState masteryState;
  final SkillProgressSnapshot updatedProgress;
  final bool supportReviewNeeded;
  final List<ReviewTicket> reviewTickets;

  bool get completed => nextAction != NextAction.retryCurrentStage;
  Set<String> get unlockedStageIds => Set.unmodifiable({
    if (unlockedStageId != null) unlockedStageId!,
    ...additionalUnlockedStageIds,
  });
  bool get unlockedNextStage => unlockedStageIds.isNotEmpty;
  Set<String> get independentSemanticFingerprints =>
      updatedProgress.independentSemanticFingerprints;
  List<LearningVariantProfile> get independentVariantProfiles =>
      updatedProgress.independentVariantProfiles;

  @Deprecated('Use independentSemanticFingerprints.')
  Set<String> get independentVariantIds => independentSemanticFingerprints;
  bool get hasDelayedIndependentSuccess =>
      updatedProgress.hasDelayedIndependentSuccess;
  bool get hasTransferIndependentSuccess =>
      updatedProgress.hasTransferIndependentSuccess;
  int get independentSuccessCount => independentSemanticFingerprints.length;
}
