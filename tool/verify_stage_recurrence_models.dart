import 'dart:io';

import '../lib/features/campaign/domain/stage_recurrence_models.dart';

void main() {
  final source = _profile(
    stageId: 'r01-c01-s02',
    relationSchemaId: 'add.combine',
    answerAstShapeId: 'binary.add',
    operandBandId: 'within-10',
    unknownPositionId: 'result',
    contextFamilyId: 'harvest',
    representationId: 'word-and-bundles',
    problemSeed: 101,
    boardSeed: 201,
    surfaceNouns: const {'grain', 'sack'},
  );
  final metadataOnly = _profile(
    stageId: 'r01-c01-s03',
    relationSchemaId: 'add.combine',
    answerAstShapeId: 'binary.add',
    operandBandId: 'within-10',
    unknownPositionId: 'result',
    contextFamilyId: 'harvest',
    representationId: 'word-and-bundles',
    problemSeed: 999,
    boardSeed: 777,
    surfaceNouns: const {'apple', 'basket'},
  );

  _expect(
    source.meaningfulFingerprint == metadataOnly.meaningfulFingerprint,
    'stage IDs, seeds, and surface nouns must not change the fingerprint',
  );
  _expect(
    source.isMetadataOnlyVariationFrom(metadataOnly),
    'metadata-only changes should be identifiable',
  );
  _expect(
    !source.isIndependentVariationFrom(metadataOnly),
    'metadata-only changes must not count as independent variation',
  );

  final contextOnly = _copy(
    source,
    stageId: 'r01-c01-s04',
    contextFamilyId: 'transport',
  );
  _expect(
    _setEquals(source.differingAxesFrom(contextOnly), {
      VariationAxis.contextFamily,
    }),
    'a single semantic change should report exactly one variation axis',
  );
  _expect(
    !source.isIndependentVariationFrom(contextOnly),
    'one educational-axis change is insufficient',
  );

  final shallowTwoAxisChange = _copy(
    source,
    stageId: 'r01-c01-s05',
    relationSchemaId: 'add.compare',
    operandBandId: 'bridge-10',
  );
  _expect(
    !source.isIndependentVariationFrom(shallowTwoAxisChange),
    'relation and operand changes need a transfer-bearing axis',
  );

  final independent = _copy(
    source,
    stageId: 'r01-c01-s07',
    operandBandId: 'bridge-10',
    contextFamilyId: 'transport',
  );
  _expect(
    source.isIndependentVariationFrom(independent),
    'two axes including context should count as independent variation',
  );
  _expect(
    _setEquals(source.differingAxesFrom(independent), {
      VariationAxis.operandBand,
      VariationAxis.contextFamily,
    }),
    'independent variation should expose its exact educational axes',
  );

  final otherSkill = _copy(
    independent,
    stageId: 'r01-c02-s01',
    primarySkillId: 'arith.mul',
  );
  _expect(
    !source.isIndependentVariationFrom(otherSkill),
    'evidence from another skill must never count as a variation',
  );

  final corePlan = StageRecurrencePlan(
    source: source,
    revisit: independent,
    kind: RevisitKind.nearTransfer,
    minimumCatalogStageGap: 3,
    maximumCatalogStageGap: 5,
  );
  _expect(corePlan.isCore && !corePlan.isSpiral, 'near transfer is core');
  _expect(
    corePlan.sourceStageId == source.stageId &&
        corePlan.revisitStageId == independent.stageId,
    'recurrence must preserve explicit source and revisit stages',
  );
  _expect(
    corePlan.acceptsCatalogStageGap(3) &&
        corePlan.acceptsCatalogStageGap(5) &&
        !corePlan.acceptsCatalogStageGap(6),
    'gap windows must be inclusive and bounded',
  );
  _expect(corePlan.isValid, 'a meaningful near-transfer plan should be valid');

  final spiralVariant = _copy(
    source,
    stageId: 'r02-c06-s04',
    answerAstShapeId: 'missing-result.add',
    representationId: 'input-output-table',
  );
  final spiralPlan = StageRecurrencePlan(
    source: source,
    revisit: spiralVariant,
    kind: RevisitKind.crossRegionTransfer,
    minimumCatalogStageGap: 35,
    maximumCatalogStageGap: 60,
  );
  _expect(
    spiralPlan.isSpiral && !spiralPlan.isCore,
    'cross-region transfer is spiral recurrence',
  );
  _expect(spiralPlan.isValid, 'cross-region transfer should validate');

  final wrongTrackWindow = StageRecurrencePlan(
    source: source,
    revisit: independent,
    kind: RevisitKind.sameRegionSpiral,
    minimumCatalogStageGap: 3,
    maximumCatalogStageGap: 5,
  );
  _expect(
    !wrongTrackWindow.isValid && !wrongTrackWindow.followsCoreSpiralGapRule,
    'a spiral recurrence must not use a core-route gap',
  );

  final clonedIndependentPlan = StageRecurrencePlan(
    source: source,
    revisit: metadataOnly,
    kind: RevisitKind.immediateIndependent,
    minimumCatalogStageGap: 2,
    maximumCatalogStageGap: 2,
  );
  _expect(
    !clonedIndependentPlan.isValid,
    'a cloned problem must not become independent evidence',
  );

  final guidedVariant = _copy(
    source,
    stageId: 'r01-c01-s03-guided',
    operandBandId: 'within-20',
  );
  final guidedPlan = StageRecurrencePlan(
    source: source,
    revisit: guidedVariant,
    kind: RevisitKind.immediateGuided,
    minimumCatalogStageGap: 1,
    maximumCatalogStageGap: 1,
  );
  _expect(
    guidedPlan.isValid && !source.isIndependentVariationFrom(guidedVariant),
    'guided repetition may vary one axis but cannot count as independent',
  );

  stdout.writeln(
    'Stage recurrence model verification passed: semantic fingerprints, '
    'independent-variation rules, and core/spiral windows.',
  );
}

LearningVariantProfile _profile({
  required String stageId,
  String primarySkillId = 'arith.add',
  required String relationSchemaId,
  required String answerAstShapeId,
  required String operandBandId,
  required String unknownPositionId,
  required String contextFamilyId,
  required String representationId,
  int? problemSeed,
  int? boardSeed,
  Set<String> surfaceNouns = const {},
}) => LearningVariantProfile(
  stageId: stageId,
  primarySkillId: primarySkillId,
  relationSchemaId: relationSchemaId,
  answerAstShapeId: answerAstShapeId,
  operandBandId: operandBandId,
  unknownPositionId: unknownPositionId,
  contextFamilyId: contextFamilyId,
  representationId: representationId,
  problemSeed: problemSeed,
  boardSeed: boardSeed,
  surfaceNouns: surfaceNouns,
);

LearningVariantProfile _copy(
  LearningVariantProfile source, {
  required String stageId,
  String? primarySkillId,
  String? relationSchemaId,
  String? answerAstShapeId,
  String? operandBandId,
  String? unknownPositionId,
  String? contextFamilyId,
  String? representationId,
}) => LearningVariantProfile(
  stageId: stageId,
  primarySkillId: primarySkillId ?? source.primarySkillId,
  relationSchemaId: relationSchemaId ?? source.relationSchemaId,
  answerAstShapeId: answerAstShapeId ?? source.answerAstShapeId,
  operandBandId: operandBandId ?? source.operandBandId,
  unknownPositionId: unknownPositionId ?? source.unknownPositionId,
  contextFamilyId: contextFamilyId ?? source.contextFamilyId,
  representationId: representationId ?? source.representationId,
  problemSeed: source.problemSeed,
  boardSeed: source.boardSeed,
  surfaceNouns: source.surfaceNouns,
);

void _expect(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}

bool _setEquals<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);
