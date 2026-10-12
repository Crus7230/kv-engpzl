enum SentenceMathChapterPhase {
  conceptDevelopment,
  retrieval,
  familiarMathNewBoard,
  integratedTransfer,
}

enum SentenceMathFocus {
  quantityRelationships,
  groupsAndShares,
  operationOrder,
  constantPatterns,
  alternatingPatterns,
  ruleInputOutput,
  commonUnits,
  massAndCapacity,
  distanceSpeedTime,
  inverseRelationships,
  unknownGroups,
  equalRelationships,
  perimeter,
  area,
  spatialRelationships,
  equivalentRatios,
  percentages,
  dataRelationships,
  arithmeticPatternMeasurement,
  relationshipAndSpace,
  integratedEvidence,
}

/// Curriculum expectations are separate from authored problem evidence. A plan
/// never promotes a stage or changes mastery, tickets, IDs, seeds, or saves.
class SentenceMathPlan {
  const SentenceMathPlan({
    required this.regionNumber,
    required this.chapterNumber,
    required this.focus,
    required this.phase,
    required this.authoringGoal,
    required this.bridgeGoal,
    this.sourceStageId,
    this.maximumQuestionCharacters = 120,
    this.maximumFactSentences = 4,
  });

  final int regionNumber;
  final int chapterNumber;
  final SentenceMathFocus focus;
  final SentenceMathChapterPhase phase;
  final String authoringGoal;

  /// Previously learned relationships to reuse before introducing a new one.
  final String bridgeGoal;
  final String? sourceStageId;

  /// Harder reasoning must not be implemented by indefinitely longer prose.
  /// Complex evidence belongs in a verified structured renderer with a text
  /// equivalent, not in a shrinking question font.
  final int maximumQuestionCharacters;
  final int maximumFactSentences;

  String get phaseGoal => switch (phase) {
    SentenceMathChapterPhase.conceptDevelopment => authoringGoal,
    SentenceMathChapterPhase.retrieval => '앞에서 익힌 관계를 다른 상황과 구할 대상으로 다시 설명합니다.',
    SentenceMathChapterPhase.familiarMathNewBoard =>
      '익숙한 수학 관계로 새 보드 효과를 익힙니다. 수학 난도는 함께 올리지 않습니다.',
    SentenceMathChapterPhase.integratedTransfer =>
      '이미 배운 관계를 연결하고 필요한 부분식과 계산 순서를 스스로 정합니다.',
  };
}
