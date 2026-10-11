/// Instructional purpose of a repeated encounter with the same learning skill.
enum RevisitKind {
  immediateGuided,
  immediateIndependent,
  nearTransfer,
  representationTransfer,
  farTransfer,
  sameRegionSpiral,
  sameRegionMastery,
  crossRegionTransfer,
  longTermRetention,
}

/// Educational dimensions that can make two encounters meaningfully distinct.
///
/// Stage IDs, random seeds, board layouts, and surface noun substitutions are
/// deliberately absent. Changing only those values must not create new
/// mastery evidence.
enum VariationAxis {
  relationSchema,
  answerAstShape,
  operandBand,
  unknownPosition,
  contextFamily,
  representation,
}

extension RevisitKindRules on RevisitKind {
  /// Core encounters stay inside the concept's initial learning route.
  bool get isCore => switch (this) {
    RevisitKind.immediateGuided ||
    RevisitKind.immediateIndependent ||
    RevisitKind.nearTransfer ||
    RevisitKind.representationTransfer ||
    RevisitKind.farTransfer => true,
    _ => false,
  };

  /// Spiral encounters deliberately return after the initial route.
  bool get isSpiral => !isCore;

  /// Guided repetition supports learning but is not independent evidence.
  bool get requiresIndependentVariation => this != RevisitKind.immediateGuided;

  int get recommendedMinimumGap => switch (this) {
    RevisitKind.immediateGuided => 1,
    RevisitKind.immediateIndependent => 2,
    RevisitKind.nearTransfer => 3,
    RevisitKind.representationTransfer => 7,
    RevisitKind.farTransfer => 6,
    RevisitKind.sameRegionSpiral => 15,
    RevisitKind.sameRegionMastery => 30,
    RevisitKind.crossRegionTransfer => 30,
    RevisitKind.longTermRetention => 75,
  };

  int get recommendedMaximumGap => switch (this) {
    RevisitKind.immediateGuided => 1,
    RevisitKind.immediateIndependent => 2,
    RevisitKind.nearTransfer => 5,
    RevisitKind.representationTransfer => 10,
    RevisitKind.farTransfer => 10,
    RevisitKind.sameRegionSpiral => 25,
    RevisitKind.sameRegionMastery => 60,
    RevisitKind.crossRegionTransfer => 60,
    RevisitKind.longTermRetention => 140,
  };
}

/// Semantic description of one authored problem variation.
///
/// [stageId], seeds, and [surfaceNouns] remain available for diagnostics, but
/// they are intentionally excluded from [meaningfulFingerprint] and variation
/// comparison. Authors must change actual instructional dimensions instead of
/// relabeling or rerolling an otherwise identical problem.
class LearningVariantProfile {
  LearningVariantProfile({
    required this.stageId,
    required this.primarySkillId,
    required this.relationSchemaId,
    required this.answerAstShapeId,
    required this.operandBandId,
    required this.unknownPositionId,
    required this.contextFamilyId,
    required this.representationId,
    this.problemSeed,
    this.boardSeed,
    Iterable<String> surfaceNouns = const [],
  }) : assert(stageId != ''),
       assert(primarySkillId != ''),
       assert(relationSchemaId != ''),
       assert(answerAstShapeId != ''),
       assert(operandBandId != ''),
       assert(unknownPositionId != ''),
       assert(contextFamilyId != ''),
       assert(representationId != ''),
       surfaceNouns = Set.unmodifiable(surfaceNouns);

  final String stageId;
  final String primarySkillId;
  final String relationSchemaId;
  final String answerAstShapeId;
  final String operandBandId;
  final String unknownPositionId;
  final String contextFamilyId;
  final String representationId;

  /// Generation metadata only. A new seed is not a new learning variation.
  final int? problemSeed;
  final int? boardSeed;

  /// Display vocabulary only. Noun substitution inside the same context
  /// family is not independent learning evidence.
  final Set<String> surfaceNouns;

  /// Stable semantic fingerprint, excluding stage identity and randomization.
  String get meaningfulFingerprint => <String>[
    primarySkillId,
    relationSchemaId,
    answerAstShapeId,
    operandBandId,
    unknownPositionId,
    contextFamilyId,
    representationId,
  ].map(_fingerprintPart).join('|');

  bool hasSamePrimarySkillAs(LearningVariantProfile other) =>
      primarySkillId == other.primarySkillId;

  bool isSemanticallyEquivalentTo(LearningVariantProfile other) =>
      hasSamePrimarySkillAs(other) &&
      meaningfulFingerprint == other.meaningfulFingerprint;

  Set<VariationAxis> differingAxesFrom(LearningVariantProfile other) {
    final axes = <VariationAxis>{};
    if (relationSchemaId != other.relationSchemaId) {
      axes.add(VariationAxis.relationSchema);
    }
    if (answerAstShapeId != other.answerAstShapeId) {
      axes.add(VariationAxis.answerAstShape);
    }
    if (operandBandId != other.operandBandId) {
      axes.add(VariationAxis.operandBand);
    }
    if (unknownPositionId != other.unknownPositionId) {
      axes.add(VariationAxis.unknownPosition);
    }
    if (contextFamilyId != other.contextFamilyId) {
      axes.add(VariationAxis.contextFamily);
    }
    if (representationId != other.representationId) {
      axes.add(VariationAxis.representation);
    }
    return Set.unmodifiable(axes);
  }

  /// Whether [other] can count as independent evidence for the same skill.
  ///
  /// At least two educational axes must differ. At least one difference must
  /// be a context, representation, unknown-position, or AST-shape change so a
  /// relation/number-band adjustment alone cannot masquerade as transfer.
  bool isIndependentVariationFrom(LearningVariantProfile other) {
    if (!hasSamePrimarySkillAs(other)) {
      return false;
    }
    final differingAxes = differingAxesFrom(other);
    if (differingAxes.length < 2) {
      return false;
    }
    return differingAxes.any(_isTransferBearingAxis);
  }

  /// True when only excluded metadata changed, including a stage ID, seed, or
  /// surface nouns.
  bool isMetadataOnlyVariationFrom(LearningVariantProfile other) =>
      stageId != other.stageId && isSemanticallyEquivalentTo(other);
}

/// Planned recurrence link between two authored problem variations.
class StageRecurrencePlan {
  StageRecurrencePlan({
    required this.source,
    required this.revisit,
    required this.kind,
    required this.minimumCatalogStageGap,
    required this.maximumCatalogStageGap,
  }) : assert(source.stageId != revisit.stageId),
       assert(source.primarySkillId == revisit.primarySkillId),
       assert(minimumCatalogStageGap >= 1),
       assert(maximumCatalogStageGap >= minimumCatalogStageGap);

  final LearningVariantProfile source;
  final LearningVariantProfile revisit;
  final RevisitKind kind;

  /// Inclusive distance in the authored catalog, not the player's route.
  ///
  /// Branching means actual elapsed completions vary. Runtime retention is
  /// therefore proved only by [ReviewTicket] completion counters.
  final int minimumCatalogStageGap;
  final int maximumCatalogStageGap;

  String get sourceStageId => source.stageId;
  String get revisitStageId => revisit.stageId;
  String get primarySkillId => source.primarySkillId;
  bool get isCore => kind.isCore;
  bool get isSpiral => kind.isSpiral;

  bool acceptsCatalogStageGap(int catalogStageGap) =>
      catalogStageGap >= minimumCatalogStageGap &&
      catalogStageGap <= maximumCatalogStageGap;

  /// The authored window may be narrower than, but must stay inside, the
  /// recommended window for its recurrence kind.
  bool get usesRecommendedGapWindow =>
      minimumCatalogStageGap >= kind.recommendedMinimumGap &&
      maximumCatalogStageGap <= kind.recommendedMaximumGap;

  /// Core recurrence remains in the first ten stages; spiral recurrence starts
  /// after the initial learning route.
  bool get followsCoreSpiralGapRule =>
      isCore ? maximumCatalogStageGap <= 10 : minimumCatalogStageGap > 10;

  bool get hasValidVariation {
    final differingAxes = source.differingAxesFrom(revisit);
    if (kind.requiresIndependentVariation) {
      return source.isIndependentVariationFrom(revisit);
    }
    return source.hasSamePrimarySkillAs(revisit) && differingAxes.isNotEmpty;
  }

  bool get isValid =>
      usesRecommendedGapWindow && followsCoreSpiralGapRule && hasValidVariation;
}

const Set<VariationAxis> _transferBearingAxes = {
  VariationAxis.answerAstShape,
  VariationAxis.unknownPosition,
  VariationAxis.contextFamily,
  VariationAxis.representation,
};

bool _isTransferBearingAxis(VariationAxis axis) =>
    _transferBearingAxes.contains(axis);

String _fingerprintPart(String value) {
  final normalized = value.trim();
  return '${normalized.length}:$normalized';
}
