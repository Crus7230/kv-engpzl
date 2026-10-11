class StageAttemptMetrics {
  const StageAttemptMetrics({
    required this.completed,
    required this.movesUsed,
    required this.meaningfulSubmissionCount,
    required this.firstMeaningfulSubmissionCorrect,
    required this.highestMathHintTierUsed,
    required this.usedDirectPathHint,
    required this.usedGuidedCompletion,
  }) : assert(movesUsed >= 0),
       assert(meaningfulSubmissionCount >= 0),
       assert(highestMathHintTierUsed >= 0);

  final bool completed;
  final int movesUsed;

  /// Syntax-invalid drafts and drag mistakes are excluded from this count.
  final int meaningfulSubmissionCount;
  final bool firstMeaningfulSubmissionCorrect;
  final int highestMathHintTierUsed;
  final bool usedDirectPathHint;
  final bool usedGuidedCompletion;
}
