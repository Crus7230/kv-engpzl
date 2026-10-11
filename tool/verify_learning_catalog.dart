import 'dart:io';

import '../lib/features/campaign/data/initial_campaign.dart'
    hide initialCampaign;
import '../lib/features/campaign/data/regional_campaign.dart' as blueprint;
import '../lib/features/campaign/domain/campaign_models.dart';
import '../lib/features/campaign/domain/campaign_validator.dart';
import '../lib/features/campaign/domain/learning_models.dart';
import '../lib/features/puzzle/data/sample_puzzles.dart';
import '../lib/features/puzzle/domain/authored_expression_checker.dart';

// The authored overlay is validated by verify_r1_authored_content.dart.
final initialCampaign = blueprint.regionalCampaign;

void main() {
  _verifyRegionalLearningPath();
  _verifyPlayableLearningSupport();
  stdout.writeln(
    'Learning catalog verification passed: 420 linked stage plans, '
    '210 explicit spiral revisits, and typed prototype support.',
  );
}

void _verifyRegionalLearningPath() {
  final stages = initialCampaign.stages.toList(growable: false);
  _expect(
    stages.length == 420,
    'The regional learning path must have 420 stages.',
  );

  final report = const CampaignValidator().validate(
    campaign: initialCampaign,
    puzzles: samplePuzzles,
    knownCharacterIds: List.generate(
      26,
      (index) => 'CHAR_${String.fromCharCode('A'.codeUnitAt(0) + index)}',
    ),
  );
  _expect(
    report.isValid,
    'Learning catalog errors: ${report.errors.map((issue) => issue.message).join(' | ')}',
  );

  final statuses = <LearningPlanStatus, int>{};
  final variantIds = <String>{};
  for (var index = 0; index < stages.length; index += 1) {
    final stage = stages[index];
    final plan = stage.learningPlan;
    statuses.update(plan.status, (count) => count + 1, ifAbsent: () => 1);
    final expectedNextId = index % 60 < 59 ? stages[index + 1].id : null;
    _expect(
      plan.nextStageId == expectedNextId &&
          initialCampaign.nextStageAfter(stage.id)?.id == expectedNextId,
      '${stage.id} must point to the next ordered regional stage.',
    );
    _expect(
      plan.primarySkillId.trim().isNotEmpty && plan.objective.trim().isNotEmpty,
      '${stage.id} must have a primary skill and learning objective.',
    );
    _expect(
      variantIds.add(plan.variantId),
      '${plan.variantId} must identify exactly one stage variant.',
    );
  }

  final revisionCount = statuses[LearningPlanStatus.requiresRevision] ?? 0;
  final plannedCount = statuses[LearningPlanStatus.planned] ?? 0;
  _expect(
    revisionCount == 296 &&
        plannedCount == 124 &&
        revisionCount + plannedCount == stages.length &&
        statuses[LearningPlanStatus.authored] == null,
    'The 210 un-authored spiral variants must remain requiresRevision: '
    '124 planned and 296 requiresRevision overall.',
  );
  final coreStages = stages.where((stage) => stage.recurrencePlan == null);
  final coreRoleCounts = <StageLearningRole, int>{};
  for (final stage in coreStages) {
    coreRoleCounts.update(
      stage.learningPlan.role,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }
  _expect(
    StageLearningRole.values.every((role) => coreRoleCounts[role] == 21),
    'The preserved 210-stage core must retain its ten-role chapter sequence.',
  );
  final revisitStages = stages.where((stage) => stage.recurrencePlan != null);
  _expect(
    revisitStages.length == 210 &&
        revisitStages.every(
          (stage) =>
              stage.learningPlan.status ==
                  LearningPlanStatus.requiresRevision &&
              !stage.recurrencePlan!.hasValidVariation &&
              stage.recurrencePlan!.revisitStageId == stage.id,
        ),
    'Every added stage must remain a source-linked, un-authored revisit until '
    'its actual numbers, context, or representation change.',
  );
  for (final region in initialCampaign.regions) {
    final regionStages = region.stages.toList(growable: false);
    final coreIds = regionStages.take(30).map((stage) => stage.id).toSet();
    final sourceIds = regionStages
        .skip(30)
        .map((stage) => stage.recurrencePlan!.sourceStageId)
        .toSet();
    _expect(
      sourceIds.length == 30 && _setEquals(sourceIds, coreIds),
      '${region.id} must revisit each core stage exactly once.',
    );
  }
  _expect(
    initialCampaign.stageById('r01-c01-s10')!.learningPlan.nextStageId ==
            'r01-c02-s01' &&
        initialCampaign.stageById('r01-c03-s10')!.learningPlan.nextStageId ==
            'r01-c04-s01' &&
        initialCampaign
            .stageById('r01-c03-s10')!
            .learningPlan
            .additionalUnlockStageIds
            .contains('r02-c01-s01') &&
        initialCampaign.stageById('r01-c06-s10')!.learningPlan.nextStageId ==
            null &&
        stages.last.learningPlan.nextStageId == null,
    'Core access gates must open the next region without redirecting a later '
    'mastery completion back to that already-open route.',
  );
  for (var regionNumber = 1; regionNumber <= 7; regionNumber += 1) {
    final gate = initialCampaign.stageById(
      'r${regionNumber.toString().padLeft(2, '0')}-c03-s10',
    )!;
    final mastery = initialCampaign.stageById(
      'r${regionNumber.toString().padLeft(2, '0')}-c06-s10',
    )!;
    _expect(
      gate.learningPlan.nextStageId ==
              'r${regionNumber.toString().padLeft(2, '0')}-c04-s01' &&
          mastery.learningPlan.nextStageId == null &&
          (regionNumber == 7
              ? gate.learningPlan.additionalUnlockStageIds.isEmpty
              : gate.learningPlan.additionalUnlockStageIds.contains(
                  'r${(regionNumber + 1).toString().padLeft(2, '0')}-c01-s01',
                )),
      'Region $regionNumber must separate its access gate from mastery end.',
    );
  }

  final detailedSkillCount = stages
      .map((stage) => stage.skillId)
      .toSet()
      .length;
  final masterySkillCount = stages
      .map((stage) => stage.learningPlan.primarySkillId)
      .toSet()
      .length;
  _expect(
    masterySkillCount >= 20 && masterySkillCount < detailedSkillCount,
    'Mastery skills must aggregate problem variants instead of duplicating every stage ID.',
  );
  final stagesByMasterySkill = <String, List<StageDefinition>>{};
  for (final stage in stages) {
    stagesByMasterySkill
        .putIfAbsent(stage.learningPlan.primarySkillId, () => [])
        .add(stage);
  }
  for (final stage in stages.where(
    (candidate) => candidate.learningPlan.status == LearningPlanStatus.planned,
  )) {
    final variants = stagesByMasterySkill[stage.learningPlan.primarySkillId]!
        .where(
          (candidate) =>
              candidate.learningPlan.status == LearningPlanStatus.planned,
        )
        .toList(growable: false);
    _expect(
      variants.length >= 2 &&
          variants.any(
            (variant) => switch (variant.learningPlan.role) {
              StageLearningRole.nearTransfer ||
              StageLearningRole.representationTransfer ||
              StageLearningRole.farTransfer => true,
              _ => false,
            },
          ),
      '${stage.learningPlan.primarySkillId} cannot be planned without two '
      'variants and a transfer opportunity.',
    );
  }
  final equationBalanceStages = stages.where(
    (stage) => stage.learningPlan.primarySkillId == 'eq.balance',
  );
  _expect(
    equationBalanceStages.isNotEmpty &&
        equationBalanceStages.every(
          (stage) =>
              stage.learningPlan.status == LearningPlanStatus.requiresRevision,
        ),
    'eq.balance must not borrow a transfer variant from a requiresRevision '
    'chapter.',
  );
  stdout.writeln(
    'Learning plan readiness: $plannedCount planned, '
    '$revisionCount requiresRevision.',
  );
}

void _verifyPlayableLearningSupport() {
  final report = const CampaignValidator().validate(
    campaign: prototypeCampaign,
    puzzles: samplePuzzles,
  );
  _expect(
    report.isValid && report.warnings.isEmpty,
    'The playable prototype must have complete, valid learning support.',
  );
  _expect(
    verticalSliceStage.learningPlan.status == LearningPlanStatus.authored &&
        verticalSliceStage.learningPlan.nextStageId == null,
    'The standalone prototype needs an authored terminal learning plan.',
  );
  final puzzle = samplePuzzles.singleWhere(
    (candidate) => candidate.id == verticalSliceStage.puzzleId,
  );
  _expect(
    puzzle.learningSupport?.hasCompletePlayableSupport ?? false,
    'The playable puzzle needs ordered hints, misconception feedback, '
    'worked steps, and a transfer prompt.',
  );
  const checker = AuthoredExpressionChecker();
  _expect(
    checker.evaluateEquation('4 × 3 = 12').isValid &&
        checker.evaluate('(5+1)×2').value.toString() == '12' &&
        !checker.evaluateEquation('4 × 3 = 11').isValid &&
        !checker.evaluate('5++2').isValid,
    'Authored explanations and transfer expressions need arithmetic checks.',
  );
}

void _expect(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}

bool _setEquals(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);
