import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/campaign/data/r1_authored_campaign.dart';
import 'package:kvm/features/campaign/domain/board_mechanic_models.dart';
import 'package:kvm/features/campaign/domain/campaign_models.dart';
import 'package:kvm/features/campaign/domain/campaign_validator.dart';
import 'package:kvm/features/progress/domain/campaign_access_policy.dart';

LinePowerRule? _power(StageDefinition stage) => stage.boardMechanicPlan.bindings
    .map((binding) => binding.rule)
    .whereType<LinePowerRule>()
    .firstOrNull;

void main() {
  test(
    'R1 has five explicit lessons and increases physical load on familiar math',
    () {
      const lessons = {
        'r01-c01-s04': BoardPowerLesson.line,
        'r01-c02-s09': BoardPowerLesson.burst,
        'r01-c02-s10': BoardPowerLesson.color,
        'r01-c04-s06': BoardPowerLesson.combination,
      };
      for (final entry in lessons.entries) {
        final stage = initialCampaign.stageById(entry.key)!;
        expect(_power(stage)!.lesson, entry.value);
        final source = initialCampaign.stageById(
          stage.boardMechanicPlan.learningSourceStageId!,
        )!;
        expect(source.isPlayable, isTrue);
        expect(
          source.mathDifficulty.tier.index,
          greaterThanOrEqualTo(stage.mathDifficulty.tier.index),
        );
        expect(
          const CampaignAccessPolicy().canEnterStage(
            stage,
            initialCampaign,
            const {},
          ),
          isFalse,
        );
      }
      final blocker = initialCampaign.stageById('r01-c02-s02')!;
      expect(blocker.boardMechanicPlan.role, BoardMechanicRole.introduce);
      expect(blocker.matchDifficulty.obstacleCount, 1);
      expect(_power(blocker), isNull);
      final layer = initialCampaign.stageById('r01-c04-s01')!;
      expect(layer.boardMechanicPlan.role, BoardMechanicRole.introduce);
      expect(layer.matchDifficulty.maxSealLayers, 2);
      final stages = initialCampaign.regions.first.stages.toList();
      for (var index = 1; index < stages.length; index++) {
        final previous = stages[index - 1];
        final stage = stages[index];
        if (stage.boardMechanicPlan.challengeLevel >
            previous.boardMechanicPlan.challengeLevel) {
          expect(
            stage.mathDifficulty.tier.index,
            lessThanOrEqualTo(previous.mathDifficulty.tier.index),
            reason: stage.id,
          );
          expect(
            stage.mathDifficulty.reasoningSteps,
            lessThanOrEqualTo(previous.mathDifficulty.reasoningSteps),
            reason: stage.id,
          );
        }
      }
    },
  );

  test(
    'the review branch cannot teach combinations before both shape lessons',
    () {
      const access = CampaignAccessPolicy();
      final stage = initialCampaign.stageById('r01-c04-s06')!;
      final source = stage.recurrencePlan!.sourceStageId;
      expect(access.canEnterStage(stage, initialCampaign, {source}), isFalse);
      expect(
        access.canEnterStage(stage, initialCampaign, {
          source,
          'r01-c02-s09',
          'r01-c02-s10',
          'r01-c04-s01',
        }),
        isTrue,
      );
      final early = initialCampaign.stageById('r01-c04-s02')!;
      expect(_power(early)!.enableBurst, isFalse);
      expect(_power(early)!.enableColor, isFalse);
      expect(
        access.canEnterStage(early, initialCampaign, {
          early.recurrencePlan!.sourceStageId,
          'r01-c01-s04',
        }),
        isFalse,
      );
      expect(
        access.canEnterStage(early, initialCampaign, {
          early.recurrencePlan!.sourceStageId,
          'r01-c01-s04',
          'r01-c04-s01',
        }),
        isTrue,
      );
    },
  );

  test('old completed replays and active v1 sessions retain their access', () {
    const access = CampaignAccessPolicy();
    final stage = initialCampaign.stageById('r01-c04-s06')!;
    final source = stage.recurrencePlan!.sourceStageId;
    expect(
      access.canEnterStage(stage, initialCampaign, {source, stage.id}),
      isTrue,
    );
    expect(
      access.canEnterStage(stage, initialCampaign, {
        source,
      }, usesLegacyBoardRules: true),
      isTrue,
    );
    expect(access.canEnterStage(stage, initialCampaign, {source}), isFalse);
  });

  test('later R1 density rises by chapter, while R3-R7 remain planned', () {
    for (final stage in initialCampaign.regions.first.stages) {
      if (stage.chapterId == 'r01-c05' || stage.chapterId == 'r01-c06') {
        expect(_power(stage)!.enableCombinations, isTrue);
        expect(
          stage.matchDifficulty.obstacleCount,
          stage.chapterId == 'r01-c05' ? 2 : 3,
        );
      }
    }
    expect(
      initialCampaign.regions
          .skip(2)
          .expand((r) => r.stages)
          .every((s) => !s.isPlayable),
      isTrue,
    );
    final laterPowers = initialCampaign.regions
        .skip(2)
        .expand((r) => r.stages)
        .map(_power)
        .whereType<LinePowerRule>();
    expect(laterPowers, isNotEmpty);
    expect(
      laterPowers.every(
        (p) => p.enableBurst && p.enableColor && p.enableCombinations,
      ),
      isTrue,
    );
    final report = const CampaignValidator().validate(
      campaign: initialCampaign,
      puzzles: authoredPuzzlesByStageId.values,
    );
    expect(
      report.errors,
      isEmpty,
      reason: report.errors
          .map((e) => '${e.location}: ${e.message}')
          .join('\n'),
    );
  });

  test(
    'a new physical lesson cannot raise math or invent an earlier source',
    () {
      final stage = initialCampaign.stageById('r01-c01-s04')!;
      final math = stage.mathDifficulty;
      final harder = _copy(
        stage,
        math: MathDifficulty(
          tier: MathDifficultyTier.m2,
          compositionTier: math.compositionTier,
          readingTier: math.readingTier,
          reasoningSteps: math.reasoningSteps,
          operatorKindCount: math.operatorKindCount,
          usesOrderOfOperations: math.usesOrderOfOperations,
          requiresParentheses: math.requiresParentheses,
        ),
      );
      expect(
        _codes(harder),
        contains(CampaignIssueCode.simultaneousDifficultyIncrease),
      );
      for (final id in ['missing-source', 'r01-c06-s10']) {
        final plan = stage.boardMechanicPlan;
        final badSource = _copy(
          stage,
          plan: BoardMechanicPlan(
            id: plan.id,
            role: plan.role,
            bindings: plan.bindings,
            challengeLevel: plan.challengeLevel,
            learningSourceStageId: id,
          ),
        );
        expect(
          _codes(badSource),
          contains(CampaignIssueCode.invalidBoardMechanicPlan),
        );
      }
    },
  );

  test('combination flags alone cannot bypass the solo shape lessons', () {
    final plan = initialCampaign.stageById('r01-c04-s06')!.boardMechanicPlan;
    final issues = const BoardMechanicSequenceValidator().validate([plan]);
    expect(
      issues.map((i) => i.code),
      contains(BoardMechanicSequenceIssueCode.powerUsedBeforeLesson),
    );
  });

  test(
    'a shape lesson may reuse learned precedence but not new parentheses',
    () {
      final stage = initialCampaign.stageById('r01-c02-s09')!;
      expect(_codes(stage), isEmpty);
      final math = stage.mathDifficulty;
      final harder = _copy(
        stage,
        math: MathDifficulty(
          tier: math.tier,
          compositionTier: math.compositionTier,
          readingTier: math.readingTier,
          reasoningSteps: math.reasoningSteps,
          operatorKindCount: math.operatorKindCount,
          usesOrderOfOperations: true,
          requiresParentheses: true,
        ),
      );
      expect(
        _codes(harder),
        contains(CampaignIssueCode.simultaneousDifficultyIncrease),
      );
      expect(
        _codes(harder),
        contains(CampaignIssueCode.invalidBoardMechanicPlan),
      );
      final newComposition = _copy(
        stage,
        math: MathDifficulty(
          tier: math.tier,
          compositionTier: CompositionTier.c3,
          readingTier: math.readingTier,
          reasoningSteps: math.reasoningSteps,
          operatorKindCount: math.operatorKindCount,
          usesOrderOfOperations: math.usesOrderOfOperations,
          requiresParentheses: false,
        ),
      );
      expect(
        _codes(newComposition),
        contains(CampaignIssueCode.simultaneousDifficultyIncrease),
      );
    },
  );
}

Set<CampaignIssueCode> _codes(StageDefinition replacement) {
  final campaign = CampaignDefinition.regional(
    id: initialCampaign.id,
    version: initialCampaign.version,
    regions: [
      for (final region in initialCampaign.regions)
        region.metadata.bindChapters([
          for (final chapter in region.chapters)
            ChapterDefinition(
              id: chapter.id,
              number: chapter.number,
              title: chapter.title,
              description: chapter.description,
              prerequisiteChapterId: chapter.prerequisiteChapterId,
              stages: [
                for (final stage in chapter.stages)
                  stage.id == replacement.id ? replacement : stage,
              ],
            ),
        ]),
    ],
  );
  return {
    for (final issue
        in const CampaignValidator()
            .validate(
              campaign: campaign,
              puzzles: authoredPuzzlesByStageId.values,
            )
            .errors)
      if (issue.location == 'stage:${replacement.id}') issue.code,
  };
}

StageDefinition _copy(
  StageDefinition stage, {
  MathDifficulty? math,
  BoardMechanicPlan? plan,
}) => StageDefinition(
  id: stage.id,
  chapterId: stage.chapterId,
  skillId: stage.skillId,
  number: stage.number,
  title: stage.title,
  conceptLabel: stage.conceptLabel,
  answerExpression: stage.answerExpression,
  puzzleId: stage.puzzleId,
  contentStatus: stage.contentStatus,
  mathDifficulty: math ?? stage.mathDifficulty,
  matchDifficulty: stage.matchDifficulty,
  boardMechanicPlan: plan ?? stage.boardMechanicPlan,
  boardVariants: stage.boardVariants,
  moveBudget: stage.moveBudget,
  starRules: stage.starRules,
  assistRules: stage.assistRules,
  learningPlan: stage.learningPlan,
  variantProfile: stage.variantProfile,
  recurrencePlan: stage.recurrencePlan,
  sentenceMathPlan: stage.sentenceMathPlan,
  seed: stage.seed,
  startingTokenIds: stage.startingTokenIds,
  buriedTokenIds: stage.buriedTokenIds,
  decoyTokenIds: stage.decoyTokenIds,
);
