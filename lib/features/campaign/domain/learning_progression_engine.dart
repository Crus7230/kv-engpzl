import 'learning_models.dart';
import 'stage_recurrence_models.dart';

/// Stateless, deterministic learning decision engine.
///
/// Stage unlocks and skill mastery are intentionally independent: completing a
/// stage always continues the route, while assisted completion schedules an
/// earlier review and marks the skill as review-due.
class LearningProgressionEngine {
  const LearningProgressionEngine({this.reviewPolicy = const ReviewPolicy()});

  final ReviewPolicy reviewPolicy;

  LearningProgressDecision decide({
    required StageLearningPlan plan,
    required LearningAttemptEvidence evidence,
    required int completedStageCountAfterAttempt,
    required SkillProgressSnapshot progress,
  }) {
    if (plan.status != LearningPlanStatus.authored) {
      throw StateError('Only an authored learning plan can be evaluated.');
    }
    if (completedStageCountAfterAttempt < 0) {
      throw ArgumentError.value(
        completedStageCountAfterAttempt,
        'completedStageCountAfterAttempt',
        'Must not be negative.',
      );
    }
    if (evidence.variantId != plan.variantId) {
      throw ArgumentError.value(
        evidence.variantId,
        'evidence.variantId',
        'Must match the stage learning-plan variant.',
      );
    }
    if (evidence.semanticFingerprint != plan.semanticFingerprint) {
      throw ArgumentError.value(
        evidence.semanticFingerprint,
        'evidence.semanticFingerprint',
        'Must match the stage learning-plan semantic fingerprint.',
      );
    }
    _validatePolicy(reviewPolicy);
    _validateProgress(plan, progress);
    final independentVariantProfiles = [...progress.independentVariantProfiles];
    final pendingReviewTickets = [...progress.pendingReviewTickets];
    final reviewTicket = _resolveReviewTicket(
      evidence.reviewTicketId,
      evidence.variantProfile,
      pendingReviewTickets,
      completedStageCountAfterAttempt,
    );

    final metrics = evidence.metrics;
    if (!metrics.completed) {
      final hasPendingSupportReview = pendingReviewTickets.any(
        (ticket) => ticket.reason == ReviewReason.supportNeeded,
      );
      final hasDueReview = pendingReviewTickets.any(
        (ticket) =>
            ticket.dueAfterCompletedStageCount <=
            completedStageCountAfterAttempt,
      );
      return LearningProgressDecision(
        nextAction: NextAction.retryCurrentStage,
        unlockedStageId: null,
        masteryState: _masteryState(
          independentVariantProfiles: independentVariantProfiles,
          hasDelayedIndependentSuccess: progress.hasDelayedIndependentSuccess,
          hasTransferIndependentSuccess: progress.hasTransferIndependentSuccess,
          supportNeeded: hasPendingSupportReview || hasDueReview,
        ),
        updatedProgress: SkillProgressSnapshot(
          skillId: progress.skillId,
          independentVariantProfiles: independentVariantProfiles,
          hasDelayedIndependentSuccess: progress.hasDelayedIndependentSuccess,
          hasTransferIndependentSuccess: progress.hasTransferIndependentSuccess,
          pendingReviewTickets: pendingReviewTickets,
        ),
        supportReviewNeeded: hasPendingSupportReview,
        reviewTickets: const [],
      );
    }
    if (metrics.meaningfulSubmissionCount == 0) {
      throw ArgumentError.value(
        metrics.meaningfulSubmissionCount,
        'evidence.metrics.meaningfulSubmissionCount',
        'A completed learning stage must contain a meaningful submission.',
      );
    }

    final supportNeeded = evidence.needsSupportReview;
    if (reviewTicket != null) {
      pendingReviewTickets.removeWhere(
        (ticket) => ticket.id == reviewTicket.id,
      );
    }
    final hasEquivalentIndependentSuccess = independentVariantProfiles.any(
      (profile) => profile.isSemanticallyEquivalentTo(evidence.variantProfile),
    );
    final hasRequiredVariation =
        independentVariantProfiles.isEmpty ||
        independentVariantProfiles.any(
          (profile) =>
              profile.isIndependentVariationFrom(evidence.variantProfile),
        );
    final isNovelIndependentSuccess =
        evidence.isIndependentSuccess &&
        !hasEquivalentIndependentSuccess &&
        hasRequiredVariation;
    if (isNovelIndependentSuccess) {
      independentVariantProfiles.add(evidence.variantProfile);
    }
    final hasDelayedIndependentSuccess =
        progress.hasDelayedIndependentSuccess ||
        (evidence.isIndependentSuccess &&
            reviewTicket != null &&
            reviewTicket.stageOffset >=
                reviewPolicy.minimumMasteryReviewOffset);
    final hasTransferIndependentSuccess =
        progress.hasTransferIndependentSuccess ||
        (isNovelIndependentSuccess && _isTransferRole(plan.role));
    final scheduledTickets = <ReviewTicket>[];
    final primaryTicket = _nextPrimaryTicket(
      plan: plan,
      reviewTicket: reviewTicket,
      pendingTickets: pendingReviewTickets,
      completedStageCountAfterAttempt: completedStageCountAfterAttempt,
      independentSuccess: evidence.isIndependentSuccess,
      supportNeeded: supportNeeded,
      sourceVariantProfile: evidence.variantProfile,
    );
    if (primaryTicket != null) {
      pendingReviewTickets
        ..clear()
        ..add(primaryTicket);
      scheduledTickets.add(primaryTicket);
    }
    // Reinforced skills need their own authored semantic profile. Scheduling a
    // ticket from the primary problem profile would create false evidence.
    final updatedPendingTickets = pendingReviewTickets;
    final hasPendingSupportReview = updatedPendingTickets.any(
      (ticket) => ticket.reason == ReviewReason.supportNeeded,
    );
    final hasDueReview = updatedPendingTickets.any(
      (ticket) =>
          ticket.dueAfterCompletedStageCount <= completedStageCountAfterAttempt,
    );
    final masteryState = _masteryState(
      independentVariantProfiles: independentVariantProfiles,
      hasDelayedIndependentSuccess: hasDelayedIndependentSuccess,
      hasTransferIndependentSuccess: hasTransferIndependentSuccess,
      supportNeeded: supportNeeded || hasPendingSupportReview || hasDueReview,
    );

    return LearningProgressDecision(
      nextAction: plan.unlockStageIds.isEmpty
          ? NextAction.completeLearningPath
          : NextAction.continueToNextStage,
      unlockedStageId: plan.nextStageId,
      additionalUnlockedStageIds: plan.additionalUnlockStageIds,
      masteryState: masteryState,
      updatedProgress: SkillProgressSnapshot(
        skillId: progress.skillId,
        independentVariantProfiles: independentVariantProfiles,
        hasDelayedIndependentSuccess: hasDelayedIndependentSuccess,
        hasTransferIndependentSuccess: hasTransferIndependentSuccess,
        pendingReviewTickets: updatedPendingTickets,
      ),
      supportReviewNeeded: supportNeeded,
      reviewTickets: scheduledTickets,
    );
  }

  void _validateProgress(
    StageLearningPlan plan,
    SkillProgressSnapshot progress,
  ) {
    if (progress.skillId != plan.primarySkillId) {
      throw ArgumentError.value(
        progress.skillId,
        'progress.skillId',
        'Must match the stage primary skill.',
      );
    }
    if (progress.pendingReviewTickets.length > 1) {
      throw ArgumentError.value(
        progress.pendingReviewTickets,
        'progress.pendingReviewTickets',
        'A skill can have at most one active review ticket.',
      );
    }
    final seenFingerprints = <String>{};
    final acceptedProfiles = <LearningVariantProfile>[];
    for (final profile in progress.independentVariantProfiles) {
      final isFirst = acceptedProfiles.isEmpty;
      final hasValidRelationship =
          isFirst ||
          acceptedProfiles.any(
            (accepted) => accepted.isIndependentVariationFrom(profile),
          );
      if (profile.primarySkillId != progress.skillId ||
          !seenFingerprints.add(profile.meaningfulFingerprint) ||
          !hasValidRelationship) {
        throw ArgumentError.value(
          progress.independentVariantProfiles,
          'progress.independentVariantProfiles',
          'Independent profiles must be unique, belong to the skill, and '
              'differ on at least two educational axes including transfer.',
        );
      }
      acceptedProfiles.add(profile);
    }
    final ticketIds = <String>{};
    for (final ticket in progress.pendingReviewTickets) {
      final offsets = reviewPolicy.offsetsFor(
        supportNeeded: ticket.reason == ReviewReason.supportNeeded,
      );
      final hasValidPolicyStep =
          ticket.policyIndex >= 0 &&
          ticket.policyIndex < offsets.length &&
          ticket.stageOffset == offsets[ticket.policyIndex];
      if (ticket.skillId != progress.skillId ||
          !ticketIds.add(ticket.id) ||
          !hasValidPolicyStep) {
        throw ArgumentError.value(
          progress.pendingReviewTickets,
          'progress.pendingReviewTickets',
          'Tickets must be unique, belong to the progress skill, and match '
              'their review-policy step.',
        );
      }
    }
  }

  ReviewTicket? _nextPrimaryTicket({
    required StageLearningPlan plan,
    required ReviewTicket? reviewTicket,
    required List<ReviewTicket> pendingTickets,
    required int completedStageCountAfterAttempt,
    required bool independentSuccess,
    required bool supportNeeded,
    required LearningVariantProfile sourceVariantProfile,
  }) {
    if (reviewTicket != null) {
      if (supportNeeded) {
        return _ticketForPolicy(
          skillId: plan.primarySkillId,
          sourceVariantId: plan.variantId,
          sourceVariantProfile: sourceVariantProfile,
          completedStageCountAfterAttempt: completedStageCountAfterAttempt,
          reason: ReviewReason.supportNeeded,
          policyIndex: 0,
        );
      }
      return _ticketForPolicy(
        skillId: plan.primarySkillId,
        sourceVariantId: plan.variantId,
        sourceVariantProfile: sourceVariantProfile,
        completedStageCountAfterAttempt: completedStageCountAfterAttempt,
        reason: reviewTicket.reason,
        policyIndex: independentSuccess
            ? reviewTicket.policyIndex + 1
            : reviewTicket.policyIndex,
      );
    }

    if (pendingTickets.isEmpty) {
      return _ticketForPolicy(
        skillId: plan.primarySkillId,
        sourceVariantId: plan.variantId,
        sourceVariantProfile: sourceVariantProfile,
        completedStageCountAfterAttempt: completedStageCountAfterAttempt,
        reason: supportNeeded
            ? ReviewReason.supportNeeded
            : ReviewReason.spacedPractice,
        policyIndex: 0,
      );
    }
    final existing = pendingTickets.single;
    if (!supportNeeded || existing.reason == ReviewReason.supportNeeded) {
      return null;
    }
    final firstSupportOffset = reviewPolicy.supportNeededStageOffsets.first;
    final nextSupportDue = completedStageCountAfterAttempt + firstSupportOffset;
    final existingDue = existing.dueAfterCompletedStageCount;
    final transitionedDue = existingDue < completedStageCountAfterAttempt
        ? completedStageCountAfterAttempt
        : existingDue < nextSupportDue
        ? existingDue
        : nextSupportDue;
    return _ticketForPolicy(
      skillId: plan.primarySkillId,
      sourceVariantId: plan.variantId,
      sourceVariantProfile: sourceVariantProfile,
      completedStageCountAfterAttempt: completedStageCountAfterAttempt,
      reason: ReviewReason.supportNeeded,
      policyIndex: 0,
      dueAfterCompletedStageCount: transitionedDue,
    );
  }

  ReviewTicket? _ticketForPolicy({
    required String skillId,
    required String sourceVariantId,
    required LearningVariantProfile sourceVariantProfile,
    required int completedStageCountAfterAttempt,
    required ReviewReason reason,
    required int policyIndex,
    int? dueAfterCompletedStageCount,
  }) {
    final offsets = reviewPolicy.offsetsFor(
      supportNeeded: reason == ReviewReason.supportNeeded,
    );
    if (policyIndex < 0 || policyIndex >= offsets.length) {
      return null;
    }
    final stageOffset = offsets[policyIndex];
    final dueCount =
        dueAfterCompletedStageCount ??
        completedStageCountAfterAttempt + stageOffset;
    return ReviewTicket(
      id:
          '$skillId|$sourceVariantId|'
          '${sourceVariantProfile.meaningfulFingerprint}|'
          '$completedStageCountAfterAttempt|'
          '${reason.name}|$policyIndex|$dueCount',
      skillId: skillId,
      sourceVariantId: sourceVariantId,
      sourceVariantProfile: sourceVariantProfile,
      policyIndex: policyIndex,
      stageOffset: stageOffset,
      dueAfterCompletedStageCount: dueCount,
      reason: reason,
    );
  }

  ReviewTicket? _resolveReviewTicket(
    String? ticketId,
    LearningVariantProfile variantProfile,
    List<ReviewTicket> pendingTickets,
    int completedStageCountAfterAttempt,
  ) {
    if (ticketId == null) {
      return null;
    }
    final matches = pendingTickets.where((ticket) => ticket.id == ticketId);
    if (matches.length != 1) {
      throw ArgumentError.value(
        ticketId,
        'evidence.reviewTicketId',
        'Must identify one pending review ticket.',
      );
    }
    final ticket = matches.single;
    if (!ticket.sourceVariantProfile.isIndependentVariationFrom(
      variantProfile,
    )) {
      throw ArgumentError.value(
        variantProfile.meaningfulFingerprint,
        'evidence.variantProfile',
        'A review ticket must differ from its source on at least two '
            'educational axes including a transfer-bearing axis.',
      );
    }
    if (ticket.dueAfterCompletedStageCount > completedStageCountAfterAttempt) {
      throw ArgumentError.value(
        ticketId,
        'evidence.reviewTicketId',
        'The review ticket is not due yet.',
      );
    }
    return ticket;
  }

  SkillMasteryState _masteryState({
    required List<LearningVariantProfile> independentVariantProfiles,
    required bool hasDelayedIndependentSuccess,
    required bool hasTransferIndependentSuccess,
    required bool supportNeeded,
  }) {
    if (supportNeeded) {
      return SkillMasteryState.reviewDue;
    }
    if (independentVariantProfiles.length <
        reviewPolicy.requiredIndependentSuccesses) {
      return SkillMasteryState.learning;
    }
    if (hasDelayedIndependentSuccess && hasTransferIndependentSuccess) {
      return SkillMasteryState.mastered;
    }
    return SkillMasteryState.provisionalMastery;
  }

  bool _isTransferRole(StageLearningRole role) => switch (role) {
    StageLearningRole.nearTransfer ||
    StageLearningRole.representationTransfer ||
    StageLearningRole.farTransfer => true,
    _ => false,
  };

  void _validatePolicy(ReviewPolicy policy) {
    _validateOffsets(policy.defaultStageOffsets, name: 'defaultStageOffsets');
    _validateOffsets(
      policy.supportNeededStageOffsets,
      name: 'supportNeededStageOffsets',
    );
    if (policy.minimumMasteryReviewOffset < 1) {
      throw ArgumentError.value(
        policy.minimumMasteryReviewOffset,
        'minimumMasteryReviewOffset',
        'Must be positive.',
      );
    }
  }

  void _validateOffsets(List<int> offsets, {required String name}) {
    if (offsets.isEmpty) {
      throw ArgumentError.value(offsets, name, 'Must not be empty.');
    }
    var previous = 0;
    for (final offset in offsets) {
      if (offset <= previous) {
        throw ArgumentError.value(
          offsets,
          name,
          'Must contain unique positive values in ascending order.',
        );
      }
      previous = offset;
    }
  }
}
