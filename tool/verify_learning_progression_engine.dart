import 'dart:io';

import '../lib/features/campaign/domain/campaign_models.dart';
import '../lib/features/campaign/domain/learning_models.dart';
import '../lib/features/campaign/domain/learning_progression_engine.dart';
import '../lib/features/campaign/domain/stage_recurrence_models.dart';

void main() {
  _verifyPolicyDefaults();
  _verifyIncompleteAttemptDoesNotUnlock();
  _verifySupportSignalsScheduleEarlyReviewAndStillUnlock();
  _verifyIndependentSuccessesAccumulateToMastery();
  _verifySemanticFingerprintsGuardMastery();
  _verifyReviewChainTransitions();
  _verifyBranchUnlocks();
  _verifyFinalStageCompletion();
  _verifyReviewTicketsAreOwnedAndDue();
  _verifyUnauthoredPlanIsRejected();
  stdout.writeln('Learning progression engine verification passed.');
}

void _verifyPolicyDefaults() {
  const policy = ReviewPolicy();
  _expect(
    _sameInts(policy.defaultStageOffsets, const [2, 6, 15, 35, 75]),
    'Default review intervals must be 2/6/15/35/75.',
  );
  _expect(
    _sameInts(policy.supportNeededStageOffsets, const [1, 3, 7, 15, 35]),
    'Support-needed review intervals must be 1/3/7/15/35.',
  );
  _expect(
    policy.requiredIndependentSuccesses == 2,
    'Two independent successes must be required by default.',
  );
  _expect(
    policy.minimumMasteryReviewOffset == 15,
    'Mastery must require an independent review at +15 or later.',
  );
}

void _verifyIncompleteAttemptDoesNotUnlock() {
  const engine = LearningProgressionEngine();
  final decision = engine.decide(
    plan: _plan(),
    evidence: _evidence(completed: false),
    completedStageCountAfterAttempt: 3,
    progress: _progress(),
  );

  _expect(
    decision.nextAction == NextAction.retryCurrentStage,
    'An incomplete attempt must retry the current stage.',
  );
  _expect(!decision.unlockedNextStage, 'Incomplete play must not unlock.');
  _expect(
    decision.reviewTickets.isEmpty,
    'Incomplete play schedules no review.',
  );
}

void _verifySupportSignalsScheduleEarlyReviewAndStillUnlock() {
  const engine = LearningProgressionEngine();
  final supportedByHint = engine.decide(
    plan: _plan(),
    evidence: _evidence(completed: true, highestMathHintTierUsed: 2),
    completedStageCountAfterAttempt: 4,
    progress: _progress(),
  );

  _expect(
    supportedByHint.nextAction == NextAction.continueToNextStage &&
        supportedByHint.unlockedStageId == 'r01-c01-s02',
    'Assisted completion must still unlock the next stage.',
  );
  _expect(
    supportedByHint.masteryState == SkillMasteryState.reviewDue,
    'Tier 2+ math hints must mark the skill review-due.',
  );
  _expect(
    _sameInts(_ticketDueCounts(supportedByHint, 'arith.add'), const [5]),
    'Support review must start with one ticket after 1 completed stage.',
  );
  _expect(
    _ticketDueCounts(supportedByHint, 'number.sense').isEmpty,
    'A reinforced skill must not receive a ticket without its own authored '
    'semantic profile.',
  );

  final misconception = engine.decide(
    plan: _plan(),
    evidence: _evidence(
      completed: true,
      misconceptionIds: const {'add-vs-multiply'},
    ),
    completedStageCountAfterAttempt: 4,
    progress: _progress(
      independentSemanticFingerprints: const {'fingerprint:variant-prior'},
    ),
  );
  _expect(
    misconception.masteryState == SkillMasteryState.reviewDue &&
        misconception.independentSuccessCount == 1,
    'A misconception must preserve prior success and schedule review.',
  );

  final failedFirstSubmission = engine.decide(
    plan: _plan(),
    evidence: _evidence(
      completed: true,
      meaningfulSubmissionCount: 2,
      firstMeaningfulSubmissionCorrect: false,
    ),
    completedStageCountAfterAttempt: 4,
    progress: _progress(),
  );
  _expect(
    failedFirstSubmission.supportReviewNeeded &&
        failedFirstSubmission.unlockedNextStage,
    'A failed first submission must schedule review without blocking progress.',
  );

  final guidedCompletion = engine.decide(
    plan: _plan(),
    evidence: _evidence(completed: true, usedGuidedCompletion: true),
    completedStageCountAfterAttempt: 4,
    progress: _progress(),
  );
  _expect(
    guidedCompletion.masteryState == SkillMasteryState.reviewDue &&
        guidedCompletion.independentSuccessCount == 0,
    'Guided completion must unlock but never count as independent mastery.',
  );

  final persistedReviewDue = engine.decide(
    plan: _plan(),
    evidence: _evidence(completed: false),
    completedStageCountAfterAttempt: 4,
    progress: supportedByHint.updatedProgress,
  );
  _expect(
    persistedReviewDue.masteryState == SkillMasteryState.reviewDue,
    'Pending support tickets must preserve review-due state.',
  );
}

void _verifyIndependentSuccessesAccumulateToMastery() {
  const engine = LearningProgressionEngine();
  final tierOneHint = engine.decide(
    plan: _plan(variantId: 'variant-hinted'),
    evidence: _evidence(
      completed: true,
      variantId: 'variant-hinted',
      highestMathHintTierUsed: 1,
    ),
    completedStageCountAfterAttempt: 7,
    progress: _progress(),
  );
  _expect(
    tierOneHint.independentSuccessCount == 0,
    'Any math hint must prevent an independent-success record.',
  );

  final first = engine.decide(
    plan: _plan(variantId: 'variant-a'),
    evidence: _evidence(
      completed: true,
      variantId: 'variant-a',
      usedDirectPathHint: true,
    ),
    completedStageCountAfterAttempt: 8,
    progress: _progress(),
  );
  _expect(
    first.masteryState == SkillMasteryState.learning &&
        first.independentSuccessCount == 1,
    'One independent success must keep the skill in learning.',
  );
  _expect(
    _sameInts(_ticketDueCounts(first, 'arith.add'), const [10]),
    'Independent success must start with one ticket after 2 stages.',
  );

  final second = engine.decide(
    plan: _plan(variantId: 'variant-b', role: StageLearningRole.farTransfer),
    evidence: _evidence(
      completed: true,
      variantId: 'variant-b',
      reviewTicketId: first.updatedProgress.pendingReviewTickets.first.id,
    ),
    completedStageCountAfterAttempt: 10,
    progress: first.updatedProgress,
  );
  _expect(
    second.masteryState == SkillMasteryState.provisionalMastery &&
        second.independentSuccessCount == 2,
    'A +2 review is too early to prove retained mastery.',
  );
  final mediumReview = engine.decide(
    plan: _plan(variantId: 'variant-c'),
    evidence: _evidence(
      completed: true,
      variantId: 'variant-c',
      reviewTicketId: second.updatedProgress.pendingReviewTickets.single.id,
    ),
    completedStageCountAfterAttempt: 16,
    progress: second.updatedProgress,
  );
  final retainedReview = engine.decide(
    plan: _plan(variantId: 'variant-d', role: StageLearningRole.farTransfer),
    evidence: _evidence(
      completed: true,
      variantId: 'variant-d',
      reviewTicketId:
          mediumReview.updatedProgress.pendingReviewTickets.single.id,
    ),
    completedStageCountAfterAttempt: 31,
    progress: mediumReview.updatedProgress,
  );
  _expect(
    retainedReview.masteryState == SkillMasteryState.mastered &&
        retainedReview.hasDelayedIndependentSuccess,
    'An independent +15 review and transfer must establish mastery.',
  );
  _expect(
    !first.supportReviewNeeded,
    'A discovery path hint must not count as math support.',
  );
}

void _verifySemanticFingerprintsGuardMastery() {
  const engine = LearningProgressionEngine();
  const sharedFingerprint = 'semantic:add-combine:within-10:harvest';
  final first = engine.decide(
    plan: _plan(
      variantId: 'semantic-stage-a',
      semanticFingerprint: sharedFingerprint,
    ),
    evidence: _evidence(
      completed: true,
      variantId: 'semantic-stage-a',
      semanticFingerprint: sharedFingerprint,
    ),
    completedStageCountAfterAttempt: 1,
    progress: _progress(),
  );

  final metadataClone = engine.decide(
    plan: _plan(
      variantId: 'semantic-stage-b',
      semanticFingerprint: sharedFingerprint,
      role: StageLearningRole.farTransfer,
    ),
    evidence: _evidence(
      completed: true,
      variantId: 'semantic-stage-b',
      semanticFingerprint: sharedFingerprint,
    ),
    completedStageCountAfterAttempt: 2,
    progress: first.updatedProgress,
  );
  _expect(
    metadataClone.independentSuccessCount == 1 &&
        !metadataClone.hasTransferIndependentSuccess,
    'A new stage ID with the same semantic fingerprint must not add '
    'independent or transfer evidence.',
  );

  final shallowProfile = _profileFor(
    'semantic-stage-shallow',
    semanticKey: sharedFingerprint,
    operandBandId: 'changed-operands-only',
  );
  final shallowClone = engine.decide(
    plan: _plan(
      variantId: 'semantic-stage-shallow',
      variantProfile: shallowProfile,
      role: StageLearningRole.farTransfer,
    ),
    evidence: _evidence(
      completed: true,
      variantId: 'semantic-stage-shallow',
      variantProfile: shallowProfile,
    ),
    completedStageCountAfterAttempt: 2,
    progress: first.updatedProgress,
  );
  _expect(
    shallowClone.independentSuccessCount == 1 &&
        !shallowClone.hasTransferIndependentSuccess,
    'Changing only operands must not create independent or transfer evidence.',
  );

  var sameFingerprintReviewRejected = false;
  try {
    engine.decide(
      plan: _plan(
        variantId: 'semantic-stage-c',
        semanticFingerprint: sharedFingerprint,
      ),
      evidence: _evidence(
        completed: true,
        variantId: 'semantic-stage-c',
        semanticFingerprint: sharedFingerprint,
        reviewTicketId: first.updatedProgress.pendingReviewTickets.single.id,
      ),
      completedStageCountAfterAttempt: 3,
      progress: metadataClone.updatedProgress,
    );
  } on ArgumentError {
    sameFingerprintReviewRejected = true;
  }
  _expect(
    sameFingerprintReviewRejected,
    'A review ticket must reject the same semantic fingerprint as its source.',
  );

  const changedFingerprint = 'semantic:add-compare:bridge-10:transport';
  final semanticReview = engine.decide(
    plan: _plan(
      variantId: 'semantic-stage-d',
      semanticFingerprint: changedFingerprint,
      role: StageLearningRole.farTransfer,
    ),
    evidence: _evidence(
      completed: true,
      variantId: 'semantic-stage-d',
      semanticFingerprint: changedFingerprint,
      reviewTicketId: first.updatedProgress.pendingReviewTickets.single.id,
    ),
    completedStageCountAfterAttempt: 3,
    progress: metadataClone.updatedProgress,
  );
  _expect(
    semanticReview.independentSuccessCount == 2 &&
        semanticReview.hasTransferIndependentSuccess,
    'A genuinely different semantic fingerprint may add mastery evidence.',
  );

  var mismatchedPlanFingerprintRejected = false;
  try {
    engine.decide(
      plan: _plan(semanticFingerprint: 'semantic:expected'),
      evidence: _evidence(
        completed: true,
        semanticFingerprint: 'semantic:unexpected',
      ),
      completedStageCountAfterAttempt: 1,
      progress: _progress(),
    );
  } on ArgumentError {
    mismatchedPlanFingerprintRejected = true;
  }
  _expect(
    mismatchedPlanFingerprintRejected,
    'A plan fingerprint must reject mismatched attempt evidence.',
  );
}

void _verifyReviewChainTransitions() {
  const engine = LearningProgressionEngine();
  final initial = engine.decide(
    plan: _plan(variantId: 'chain-initial'),
    evidence: _evidence(completed: true, variantId: 'chain-initial'),
    completedStageCountAfterAttempt: 10,
    progress: _progress(),
  );
  final first = initial.updatedProgress.pendingReviewTickets.single;
  _expect(
    first.reason == ReviewReason.spacedPractice &&
        first.policyIndex == 0 &&
        first.stageOffset == 2 &&
        first.dueAfterCompletedStageCount == 12,
    'Initial success must create only the first default-policy ticket.',
  );

  final independent = engine.decide(
    plan: _plan(variantId: 'chain-independent'),
    evidence: _evidence(
      completed: true,
      variantId: 'chain-independent',
      reviewTicketId: first.id,
    ),
    completedStageCountAfterAttempt: 12,
    progress: initial.updatedProgress,
  );
  final second = independent.updatedProgress.pendingReviewTickets.single;
  _expect(
    second.reason == ReviewReason.spacedPractice &&
        second.policyIndex == 1 &&
        second.stageOffset == 6 &&
        second.dueAfterCompletedStageCount == 18,
    'Independent review success must advance by one policy step only.',
  );

  final tierOne = engine.decide(
    plan: _plan(variantId: 'chain-tier-one'),
    evidence: _evidence(
      completed: true,
      variantId: 'chain-tier-one',
      reviewTicketId: second.id,
      highestMathHintTierUsed: 1,
    ),
    completedStageCountAfterAttempt: 18,
    progress: independent.updatedProgress,
  );
  final repeated = tierOne.updatedProgress.pendingReviewTickets.single;
  _expect(
    repeated.reason == ReviewReason.spacedPractice &&
        repeated.policyIndex == 1 &&
        repeated.stageOffset == 6 &&
        repeated.dueAfterCompletedStageCount == 24,
    'Tier 1 support must repeat the current interval without moving backward.',
  );

  final supported = engine.decide(
    plan: _plan(variantId: 'chain-supported'),
    evidence: _evidence(
      completed: true,
      variantId: 'chain-supported',
      reviewTicketId: repeated.id,
      highestMathHintTierUsed: 2,
    ),
    completedStageCountAfterAttempt: 24,
    progress: tierOne.updatedProgress,
  );
  final supportFirst = supported.updatedProgress.pendingReviewTickets.single;
  _expect(
    supportFirst.reason == ReviewReason.supportNeeded &&
        supportFirst.policyIndex == 0 &&
        supportFirst.stageOffset == 1 &&
        supportFirst.dueAfterCompletedStageCount == 25,
    'Tier 2+ support must replace the prior chain with support policy step 0.',
  );

  final supportSecondDecision = engine.decide(
    plan: _plan(variantId: 'chain-support-second'),
    evidence: _evidence(
      completed: true,
      variantId: 'chain-support-second',
      reviewTicketId: supportFirst.id,
    ),
    completedStageCountAfterAttempt: 25,
    progress: supported.updatedProgress,
  );
  final supportSecond =
      supportSecondDecision.updatedProgress.pendingReviewTickets.single;
  _expect(
    supportSecond.policyIndex == 1 &&
        supportSecond.stageOffset == 3 &&
        supportSecond.dueAfterCompletedStageCount == 28,
    'Support review success must advance to the next support interval.',
  );

  final supportThirdDecision = engine.decide(
    plan: _plan(variantId: 'chain-support-third'),
    evidence: _evidence(
      completed: true,
      variantId: 'chain-support-third',
      reviewTicketId: supportSecond.id,
    ),
    completedStageCountAfterAttempt: 28,
    progress: supportSecondDecision.updatedProgress,
  );
  final supportThird =
      supportThirdDecision.updatedProgress.pendingReviewTickets.single;
  _expect(
    supportThird.policyIndex == 2 &&
        supportThird.stageOffset == 7 &&
        supportThird.dueAfterCompletedStageCount == 35,
    'The support chain must reach its third interval without duplicates.',
  );

  final supportFourthDecision = engine.decide(
    plan: _plan(variantId: 'chain-support-fourth'),
    evidence: _evidence(
      completed: true,
      variantId: 'chain-support-fourth',
      reviewTicketId: supportThird.id,
    ),
    completedStageCountAfterAttempt: 35,
    progress: supportThirdDecision.updatedProgress,
  );
  final supportFourth =
      supportFourthDecision.updatedProgress.pendingReviewTickets.single;
  _expect(
    supportFourth.policyIndex == 3 &&
        supportFourth.stageOffset == 15 &&
        supportFourth.dueAfterCompletedStageCount == 50,
    'The support chain must continue to the +15 retention interval.',
  );

  final supportFifthDecision = engine.decide(
    plan: _plan(variantId: 'chain-support-fifth'),
    evidence: _evidence(
      completed: true,
      variantId: 'chain-support-fifth',
      reviewTicketId: supportFourth.id,
    ),
    completedStageCountAfterAttempt: 50,
    progress: supportFourthDecision.updatedProgress,
  );
  final supportFifth =
      supportFifthDecision.updatedProgress.pendingReviewTickets.single;
  _expect(
    supportFifth.policyIndex == 4 &&
        supportFifth.stageOffset == 35 &&
        supportFifth.dueAfterCompletedStageCount == 85,
    'The support chain must finish with a +35 long-term interval.',
  );

  final finished = engine.decide(
    plan: _plan(variantId: 'chain-finished'),
    evidence: _evidence(
      completed: true,
      variantId: 'chain-finished',
      reviewTicketId: supportFifth.id,
    ),
    completedStageCountAfterAttempt: 85,
    progress: supportFifthDecision.updatedProgress,
  );
  _expect(
    finished.updatedProgress.pendingReviewTickets.isEmpty &&
        finished.reviewTickets.every((ticket) => ticket.skillId != 'arith.add'),
    'Independent success at the final interval must end the primary chain.',
  );
}

void _verifyFinalStageCompletion() {
  const engine = LearningProgressionEngine();
  final dueTicket = _ticket(
    id: 'final-review',
    dueAfterCompletedStageCount: 30,
    policyIndex: 2,
    stageOffset: 15,
  );
  final decision = engine.decide(
    plan: _plan(
      nextStageId: null,
      variantId: 'variant-final',
      role: StageLearningRole.farTransfer,
    ),
    evidence: _evidence(
      completed: true,
      variantId: 'variant-final',
      reviewTicketId: dueTicket.id,
    ),
    completedStageCountAfterAttempt: 30,
    progress: _progress(
      independentSemanticFingerprints: const {'fingerprint:variant-prior'},
      pendingReviewTickets: [dueTicket],
    ),
  );
  _expect(
    decision.nextAction == NextAction.completeLearningPath &&
        !decision.unlockedNextStage &&
        decision.masteryState == SkillMasteryState.mastered,
    'A final authored stage must complete its path without a phantom unlock.',
  );
}

void _verifyBranchUnlocks() {
  const engine = LearningProgressionEngine();
  final decision = engine.decide(
    plan: _plan(
      nextStageId: 'r01-c04-s01',
      additionalUnlockStageIds: const {'r02-c01-s01'},
    ),
    evidence: _evidence(completed: true),
    completedStageCountAfterAttempt: 30,
    progress: _progress(),
  );
  _expect(
    decision.unlockedStageIds.length == 2 &&
        decision.unlockedStageIds.contains('r01-c04-s01') &&
        decision.unlockedStageIds.contains('r02-c01-s01'),
    'A core access gate must unlock the mastery branch and next region together.',
  );
}

void _verifyReviewTicketsAreOwnedAndDue() {
  const engine = LearningProgressionEngine();
  final dueTicket = _ticket(
    id: 'due-maintenance-review',
    dueAfterCompletedStageCount: 10,
  );
  final dueDecision = engine.decide(
    plan: _plan(),
    evidence: _evidence(completed: false),
    completedStageCountAfterAttempt: 10,
    progress: _progress(
      independentSemanticFingerprints: const {'fingerprint:variant-prior'},
      pendingReviewTickets: [dueTicket],
    ),
  );
  _expect(
    dueDecision.masteryState == SkillMasteryState.reviewDue,
    'A due normal review ticket must surface review-due state.',
  );
  final futureTicket = _ticket(
    id: 'future-review',
    dueAfterCompletedStageCount: 12,
  );
  var earlyTicketRejected = false;
  try {
    engine.decide(
      plan: _plan(),
      evidence: _evidence(completed: true, reviewTicketId: futureTicket.id),
      completedStageCountAfterAttempt: 10,
      progress: _progress(pendingReviewTickets: [futureTicket]),
    );
  } on ArgumentError {
    earlyTicketRejected = true;
  }
  _expect(
    earlyTicketRejected,
    'A review attempt must not consume a ticket before it is due.',
  );

  var foreignSkillRejected = false;
  try {
    engine.decide(
      plan: _plan(),
      evidence: _evidence(completed: true),
      completedStageCountAfterAttempt: 10,
      progress: _progress(skillId: 'arith.subtract'),
    );
  } on ArgumentError {
    foreignSkillRejected = true;
  }
  _expect(
    foreignSkillRejected,
    'Progress evidence from another skill must be rejected.',
  );
}

void _verifyUnauthoredPlanIsRejected() {
  const engine = LearningProgressionEngine();
  var rejected = false;
  try {
    engine.decide(
      plan: _plan(status: LearningPlanStatus.planned),
      evidence: _evidence(completed: true),
      completedStageCountAfterAttempt: 1,
      progress: _progress(),
    );
  } on StateError {
    rejected = true;
  }
  _expect(
    rejected,
    'A planned learning plan must not be evaluated as authored.',
  );
}

StageLearningPlan _plan({
  LearningPlanStatus status = LearningPlanStatus.authored,
  String? nextStageId = 'r01-c01-s02',
  String variantId = 'variant-a',
  String? semanticFingerprint,
  LearningVariantProfile? variantProfile,
  StageLearningRole role = StageLearningRole.guidedPractice,
  Set<String> additionalUnlockStageIds = const {},
}) => StageLearningPlan(
  status: status,
  primarySkillId: 'arith.add',
  prerequisiteSkillIds: const {'number.sense'},
  reinforcedSkillIds: const {'number.sense'},
  variantId: variantId,
  variantProfile:
      variantProfile ??
      _profileFor(
        variantId,
        semanticKey: semanticFingerprint ?? _semanticFingerprintFor(variantId),
      ),
  role: role,
  objective: '두 양을 하나의 덧셈식으로 나타낸다.',
  nextStageId: nextStageId,
  additionalUnlockStageIds: additionalUnlockStageIds,
);

LearningAttemptEvidence _evidence({
  required bool completed,
  int meaningfulSubmissionCount = 1,
  bool firstMeaningfulSubmissionCorrect = true,
  int highestMathHintTierUsed = 0,
  bool usedDirectPathHint = false,
  bool usedGuidedCompletion = false,
  String variantId = 'variant-a',
  String? semanticFingerprint,
  LearningVariantProfile? variantProfile,
  String? reviewTicketId,
  Set<String> misconceptionIds = const {},
}) => LearningAttemptEvidence(
  variantId: variantId,
  variantProfile:
      variantProfile ??
      _profileFor(
        variantId,
        semanticKey: semanticFingerprint ?? _semanticFingerprintFor(variantId),
      ),
  reviewTicketId: reviewTicketId,
  metrics: StageAttemptMetrics(
    completed: completed,
    movesUsed: completed ? 4 : 10,
    meaningfulSubmissionCount: meaningfulSubmissionCount,
    firstMeaningfulSubmissionCorrect: firstMeaningfulSubmissionCorrect,
    highestMathHintTierUsed: highestMathHintTierUsed,
    usedDirectPathHint: usedDirectPathHint,
    usedGuidedCompletion: usedGuidedCompletion,
  ),
  misconceptionIds: misconceptionIds,
);

SkillProgressSnapshot _progress({
  String skillId = 'arith.add',
  Set<String> independentSemanticFingerprints = const {},
  bool hasDelayedIndependentSuccess = false,
  bool hasTransferIndependentSuccess = false,
  List<ReviewTicket> pendingReviewTickets = const [],
}) => SkillProgressSnapshot(
  skillId: skillId,
  independentVariantProfiles: [
    for (final fingerprint in independentSemanticFingerprints)
      _profileFor(
        fingerprint.replaceFirst('fingerprint:', ''),
        semanticKey: fingerprint,
        primarySkillId: skillId,
      ),
  ],
  hasDelayedIndependentSuccess: hasDelayedIndependentSuccess,
  hasTransferIndependentSuccess: hasTransferIndependentSuccess,
  pendingReviewTickets: pendingReviewTickets,
);

ReviewTicket _ticket({
  required String id,
  required int dueAfterCompletedStageCount,
  int policyIndex = 0,
  int stageOffset = 2,
  String sourceSemanticFingerprint = 'fingerprint:variant-source',
}) => ReviewTicket(
  id: id,
  skillId: 'arith.add',
  sourceVariantId: 'variant-source',
  sourceVariantProfile: _profileFor(
    'variant-source',
    semanticKey: sourceSemanticFingerprint,
  ),
  policyIndex: policyIndex,
  stageOffset: stageOffset,
  dueAfterCompletedStageCount: dueAfterCompletedStageCount,
  reason: ReviewReason.spacedPractice,
);

String _semanticFingerprintFor(String variantId) => 'fingerprint:$variantId';

LearningVariantProfile _profileFor(
  String variantId, {
  required String semanticKey,
  String primarySkillId = 'arith.add',
  String? operandBandId,
}) => LearningVariantProfile(
  stageId: variantId,
  primarySkillId: primarySkillId,
  relationSchemaId: 'add.combine',
  answerAstShapeId: 'n+n',
  operandBandId: operandBandId ?? 'operands:$semanticKey',
  unknownPositionId: 'result',
  contextFamilyId: 'context:$semanticKey',
  representationId: 'word-problem',
);

List<int> _ticketDueCounts(LearningProgressDecision decision, String skillId) =>
    [
      for (final ticket in decision.reviewTickets)
        if (ticket.skillId == skillId) ticket.dueAfterCompletedStageCount,
    ];

bool _sameInts(List<int> actual, List<int> expected) {
  if (actual.length != expected.length) {
    return false;
  }
  for (var index = 0; index < actual.length; index += 1) {
    if (actual[index] != expected[index]) {
      return false;
    }
  }
  return true;
}

void _expect(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}
