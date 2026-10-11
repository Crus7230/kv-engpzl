import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/campaign/data/initial_campaign.dart';
import '../../../lib/features/campaign/data/r1_authored_campaign.dart';
import '../../../lib/features/campaign/data/regional_campaign.dart';
import '../../../lib/features/campaign/domain/campaign_models.dart';
import '../../../lib/features/campaign/domain/board_mechanic_models.dart';
import '../../../lib/features/campaign/domain/campaign_validator.dart';
import '../../../lib/features/campaign/domain/learning_models.dart';
import '../../../lib/features/campaign/domain/stage_recurrence_models.dart';
import '../../../lib/features/puzzle/domain/authored_expression_checker.dart';
import '../../../lib/features/puzzle/domain/equation_token.dart';
import '../../../lib/features/puzzle/domain/puzzle.dart';

void main() {
  test(
    '60 authored alpha stages overlay420 slots without changing blueprint',
    () {
      expect(initialCampaign.stages.length, 420);
      expect(
        initialCampaign.stages.where((stage) => stage.isPlayable).length,
        60,
      );
      expect(r1PuzzlesByStageId.length, 60);
      expect(
        regionalCampaign.stages.every((stage) => !stage.hasAuthoredPuzzle),
        isTrue,
      );
      final report = const CampaignValidator().validate(
        campaign: initialCampaign,
        puzzles: r1PuzzlesByStageId.values,
      );
      expect(
        report.errors,
        isEmpty,
        reason: report.errors.map((issue) => issue.message).join('\n'),
      );
      expect(report.warnings.length, 360);
      expect(
        initialCampaign.stageById('r07-c01-s01')!.contentStatus,
        StageContentStatus.planned,
      );
      expect(
        initialCampaign.stageById('r07-c01-s10')!.learningPlan.status,
        LearningPlanStatus.planned,
      );
    },
  );

  test('every R1 chapter has ten real concise problems', () {
    final r1 = initialCampaign.regions.first;
    expect(r1.chapters.length, 6);
    for (final chapter in r1.chapters) {
      expect(chapter.stages.length, 10);
      for (final stage in chapter.stages) {
        final puzzle = r1PuzzlesByStageId[stage.id]!;
        expect(stage.isPlayable, isTrue);
        expect(puzzle.question.length, lessThanOrEqualTo(110));
        expect(puzzle.question, isNot(contains('제작 예정')));
        expect(puzzle.tokens.length, inInclusiveRange(3, 7));
      }
    }
    expect(
      initialCampaign.regions
          .skip(1)
          .expand((region) => region.stages)
          .every((stage) => !stage.isPlayable),
      isTrue,
    );
  });

  test('all answers use exact unique manifests and ASTs', () {
    for (final entry in r1PuzzlesByStageId.entries) {
      final puzzle = entry.value;
      final stage = initialCampaign.stageById(entry.key)!;
      final byId = {for (final token in puzzle.tokens) token.id: token};
      final expression = [
        for (final id in r1AnswerTokenIdsByStageId[entry.key]!) byId[id]!,
      ];
      expect(byId.length, puzzle.tokens.length);
      expect(
        const PuzzleValidator().validate(puzzle, expression).isCorrect,
        isTrue,
        reason: entry.key,
      );
      expect(
        stage.startingTokenIds.intersection(stage.buriedTokenIds),
        isEmpty,
      );
      expect({
        ...stage.startingTokenIds,
        ...stage.buriedTokenIds,
      }, puzzle.requiredTokenIds);
      expect(stage.buriedTokenIds.length, inInclusiveRange(2, 3));
      expect(
        stage.buriedTokenIds,
        contains(
          puzzle.tokens
              .lastWhere((token) => token.kind == EquationTokenKind.number)
              .id,
        ),
      );
      expect(
        puzzle.tokens
            .where((token) => stage.buriedTokenIds.contains(token.id))
            .any((token) => token.isParenthesis),
        isFalse,
      );
      expect(
        const PuzzleValidator()
            .validate(puzzle, expression.sublist(0, expression.length - 1))
            .isCorrect,
        isFalse,
        reason: 'all quantities in the manifest remain required',
      );
    }
  });

  test(
    'all support has3 ordered hints5 feedback categories2 true worked steps',
    () {
      const checker = AuthoredExpressionChecker();
      for (final puzzle in r1PuzzlesByStageId.values) {
        final support = puzzle.learningSupport!;
        expect(support.hasCompletePlayableSupport, isTrue);
        expect(puzzle.visualDescription, isNotEmpty);
        for (final worked in support.workedSolutionSteps) {
          expect(checker.evaluateEquation(worked.expression).isValid, isTrue);
        }
        expect(
          checker
              .evaluateEquation(support.workedSolutionSteps.last.expression)
              .value,
          puzzle.target,
        );
        expect(
          checker.evaluate(support.transferPrompt.expectedExpression).isValid,
          isTrue,
        );
      }
    },
  );

  test(
    'C04 contains10 source-linked meaning changes, not seed or noun rerolls',
    () {
      final reviews = initialCampaign.stages
          .where((stage) => stage.chapterId == 'r01-c04')
          .toList();
      expect(reviews.length, 10);
      for (final review in reviews) {
        final source = initialCampaign.stageById(
          review.recurrencePlan!.sourceStageId,
        )!;
        expect(source.isPlayable, isTrue);
        expect(
          review.variantProfile.isIndependentVariationFrom(
            source.variantProfile,
          ),
          isTrue,
        );
        expect(
          review.variantProfile.differingAxesFrom(source.variantProfile).length,
          greaterThanOrEqualTo(2),
        );
        expect(
          source.learningPlan.additionalUnlockStageIds,
          contains(review.id),
        );
        expect(
          review.recurrencePlan!.source.meaningfulFingerprint,
          source.variantProfile.meaningfulFingerprint,
        );
      }
      expect(reviews.first.recurrencePlan!.sourceStageId, 'r01-c01-s06');
      expect(reviews.last.recurrencePlan!.sourceStageId, 'r01-c02-s05');
    },
  );

  test(
    'C05 and C06 retain independent source links without early branch unlocks',
    () {
      for (final revisit in initialCampaign.regions.first.stages.where(
        (stage) => stage.chapterId == 'r01-c05' || stage.chapterId == 'r01-c06',
      )) {
        final source = initialCampaign.stageById(
          revisit.recurrencePlan!.sourceStageId,
        )!;
        expect(source.isPlayable, isTrue);
        expect(revisit.isPlayable, isTrue);
        expect(revisit.learningPlan.status, LearningPlanStatus.authored);
        expect(
          revisit.recurrencePlan!.source.meaningfulFingerprint,
          source.variantProfile.meaningfulFingerprint,
        );
        expect(
          revisit.variantProfile.isIndependentVariationFrom(
            source.variantProfile,
          ),
          isTrue,
          reason: revisit.id,
        );
        expect(
          source.learningPlan.additionalUnlockStageIds,
          isNot(contains(revisit.id)),
          reason:
              '${revisit.id} waits for its chapter, not just source completion',
        );
      }
      expect(
        initialCampaign.stageById('r01-c05-s01')!.recurrencePlan!.sourceStageId,
        'r01-c02-s06',
      );
      expect(
        initialCampaign.stageById('r01-c05-s10')!.recurrencePlan!.sourceStageId,
        'r01-c03-s05',
      );
      expect(
        initialCampaign.stageById('r01-c06-s01')!.recurrencePlan!.sourceStageId,
        'r01-c01-s01',
      );
      expect(
        initialCampaign.stageById('r01-c06-s10')!.recurrencePlan!.sourceStageId,
        'r01-c03-s10',
      );
    },
  );

  test('parentheses are real unique tokens and remain in the intended AST', () {
    for (final id in [
      'r01-c03-s02',
      'r01-c03-s05',
      'r01-c03-s06',
      'r01-c03-s09',
      'r01-c03-s10',
      'r01-c05-s07',
      'r01-c05-s10',
      'r01-c06-s06',
      'r01-c06-s09',
      'r01-c06-s10',
    ]) {
      final puzzle = r1PuzzlesByStageId[id]!;
      final stage = initialCampaign.stageById(id)!;
      expect(puzzle.tokens.where((token) => token.isParenthesis).length, 2);
      expect(stage.mathDifficulty.requiresParentheses, isTrue);
      expect(stage.mathDifficulty.usesOrderOfOperations, isTrue);
      final withoutParentheses = puzzle.tokens
          .where((token) => !token.isParenthesis)
          .toList();
      expect(
        const PuzzleValidator().validate(puzzle, withoutParentheses).isCorrect,
        isFalse,
        reason: id,
      );
    }
  });

  test('C05 introduces one effect at a time before C06 combines them', () {
    final firstLayered = initialCampaign.stageById('r01-c05-s01')!;
    final firstPower = initialCampaign.stageById('r01-c05-s06')!;
    expect(firstLayered.boardMechanicPlan.role, BoardMechanicRole.introduce);
    expect(firstLayered.boardMechanicPlan.advancedMechanicIds, {
      BoardMechanicId.layeredSeal,
    });
    expect(firstPower.boardMechanicPlan.role, BoardMechanicRole.introduce);
    expect(firstPower.boardMechanicPlan.advancedMechanicIds, {
      BoardMechanicId.linePower,
    });
    for (final stage in initialCampaign.regions.first.stages.where(
      (stage) => stage.chapterId == 'r01-c06',
    )) {
      expect(stage.boardMechanicPlan.role, BoardMechanicRole.mixed);
      expect(stage.boardMechanicPlan.advancedMechanicIds, {
        BoardMechanicId.layeredSeal,
        BoardMechanicId.linePower,
      });
      expect(stage.matchDifficulty.maxSealLayers, 2);
      expect(stage.moveBudget.referenceMoves, 8);
      expect(stage.moveBudget.parMoves, 10);
      expect(stage.moveLimit, 16);
    }
  });

  test(
    'legacy core identities seeds fixtures and next region gate stay stable',
    () {
      for (final entry in r1PuzzlesByStageId.entries) {
        final stage = initialCampaign.stageById(entry.key)!;
        final original = regionalCampaign.stageById(entry.key)!;
        expect(stage.id, original.id);
        expect(stage.skillId, original.skillId);
        expect(stage.puzzleId, original.puzzleId);
        expect(stage.seed, original.seed);
        expect(
          stage.learningPlan.nextStageId,
          original.learningPlan.nextStageId,
        );
        for (final variant in stage.boardVariants.variants) {
          final oldVariant = original.boardVariants.variantFor(variant.config);
          expect(variant.seed, oldVariant.seed);
          expect(variant.fixtureId, oldVariant.fixtureId);
        }
      }
      expect(
        initialCampaign
            .stageById('r01-c03-s10')!
            .learningPlan
            .additionalUnlockStageIds,
        contains('r02-c01-s01'),
      );
    },
  );

  test(
    'planned path may use authored evidence but authored cannot reuse identical profiles',
    () {
      final first = initialCampaign.stageById('r01-c02-s03')!;
      final second = initialCampaign.stageById('r01-c04-s08')!;
      final secondProfile = LearningVariantProfile(
        stageId: second.id,
        primarySkillId: first.variantProfile.primarySkillId,
        relationSchemaId: first.variantProfile.relationSchemaId,
        answerAstShapeId: first.variantProfile.answerAstShapeId,
        operandBandId: first.variantProfile.operandBandId,
        unknownPositionId: first.variantProfile.unknownPositionId,
        contextFamilyId: first.variantProfile.contextFamilyId,
        representationId: first.variantProfile.representationId,
      );
      final campaign = CampaignDefinition(
        id: 'test-identical-authored',
        version: 4,
        chapters: [
          ChapterDefinition(
            id: 'test-chapter',
            number: 1,
            title: '검증',
            description: '검증',
            prerequisiteChapterId: null,
            stages: [
              _copyForTest(
                first,
                number: 1,
                nextStageId: second.id,
                profile: first.variantProfile,
              ),
              _copyForTest(
                second,
                number: 2,
                nextStageId: null,
                profile: secondProfile,
              ),
            ],
          ),
        ],
      );
      final report = const CampaignValidator().validate(
        campaign: campaign,
        puzzles: [
          r1PuzzlesByStageId[first.id]!,
          r1PuzzlesByStageId[second.id]!,
        ],
      );
      expect(
        report.errors.map((issue) => issue.code),
        contains(CampaignIssueCode.insufficientMasteryVariants),
      );
    },
  );
}

StageDefinition _copyForTest(
  StageDefinition stage, {
  required int number,
  required String? nextStageId,
  required LearningVariantProfile profile,
}) => StageDefinition(
  id: stage.id,
  chapterId: 'test-chapter',
  skillId: stage.skillId,
  number: number,
  title: stage.title,
  conceptLabel: stage.conceptLabel,
  answerExpression: stage.answerExpression,
  puzzleId: stage.puzzleId,
  contentStatus: stage.contentStatus,
  mathDifficulty: stage.mathDifficulty,
  matchDifficulty: stage.matchDifficulty,
  boardMechanicPlan: stage.boardMechanicPlan,
  boardVariants: stage.boardVariants,
  moveBudget: stage.moveBudget,
  starRules: stage.starRules,
  assistRules: stage.assistRules,
  learningPlan: StageLearningPlan(
    status: LearningPlanStatus.authored,
    primarySkillId: profile.primarySkillId,
    prerequisiteSkillIds: const {},
    reinforcedSkillIds: const {},
    variantId: stage.id,
    variantProfile: profile,
    role: StageLearningRole.nearTransfer,
    objective: stage.learningPlan.objective,
    nextStageId: nextStageId,
  ),
  variantProfile: profile,
  seed: stage.seed,
  startingTokenIds: stage.startingTokenIds,
  buriedTokenIds: stage.buriedTokenIds,
);
