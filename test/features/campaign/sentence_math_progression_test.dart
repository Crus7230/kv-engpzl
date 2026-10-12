import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/campaign/data/initial_campaign.dart';
import '../../../lib/features/campaign/data/r1_authored_campaign.dart';
import '../../../lib/features/campaign/data/regional_campaign.dart';
import '../../../lib/features/campaign/data/sentence_math_curriculum.dart';
import '../../../lib/features/campaign/domain/sentence_math_plan.dart';
import '../../../lib/features/campaign/domain/sentence_math_validator.dart';
import '../../../lib/features/discovery/data/discovery_runtime_catalog.dart';
import '../../../lib/features/puzzle/domain/puzzle.dart';
import '../../../lib/features/puzzle/domain/equation_engine.dart';
import '../../../lib/features/puzzle/domain/sentence_math_problem.dart';

void main() {
  test('all 420 slots carry a continuous 21-concept interpretation route', () {
    final focuses = <SentenceMathFocus>{};
    for (final stage in regionalCampaign.stages) {
      final plan = stage.sentenceMathPlan!;
      expect(
        const SentenceMathValidator().validatePlan(stage),
        isEmpty,
        reason: stage.id,
      );
      expect(plan.maximumQuestionCharacters, 120);
      expect(plan.bridgeGoal, isNotEmpty);
      expect(stage.isPlayable, isFalse);
      if (plan.chapterNumber <= 3) {
        expect(plan.phase, SentenceMathChapterPhase.conceptDevelopment);
        focuses.add(plan.focus);
      } else {
        final source = regionalCampaign.stageById(plan.sourceStageId!)!;
        expect(plan.focus, source.sentenceMathPlan!.focus);
        expect(plan.sourceStageId, stage.recurrencePlan!.sourceStageId);
        expect(plan.phase, switch (plan.chapterNumber) {
          4 => SentenceMathChapterPhase.retrieval,
          5 => SentenceMathChapterPhase.familiarMathNewBoard,
          _ => SentenceMathChapterPhase.integratedTransfer,
        });
      }
    }
    expect(focuses, SentenceMathFocus.values.toSet());
  });

  test(
    'authored R1/R2 adopts contracts without changing IDs, seeds or routes',
    () {
      for (final stage in initialCampaign.stages) {
        final blueprint = regionalCampaign.stageById(stage.id)!;
        expect(stage.sentenceMathPlan, same(blueprint.sentenceMathPlan));
        expect(stage.seed, blueprint.seed);
        expect(stage.puzzleId, blueprint.puzzleId);
        expect(
          stage.learningPlan.nextStageId,
          blueprint.learningPlan.nextStageId,
        );
        if (!stage.isPlayable) continue;
        final puzzle = authoredPuzzlesByStageId[stage.id]!;
        expect(
          const SentenceMathValidator().validate(stage, puzzle),
          isEmpty,
          reason: stage.id,
        );
        expect(puzzle.sentenceMath!.fullText, puzzle.question);
        expect(discoveryRuntimeCatalog.resolve(stage).puzzle, same(puzzle));
      }
      expect(
        initialCampaign.stages.where((stage) => stage.isPlayable),
        hasLength(120),
      );
      expect(discoveryRuntimeCatalog.contains('r02-c01-s01'), isTrue);
      expect(
        () => discoveryRuntimeCatalog.resolve(
          initialCampaign.stageById('r03-c01-s01')!,
        ),
        throwsStateError,
      );
    },
  );

  test(
    'chapter phases do not substitute a plan for authored review evidence',
    () {
      expect(
        () => sentenceMathPlanFor(regionNumber: 2, chapterNumber: 4),
        throwsArgumentError,
      );
      expect(
        () => sentenceMathPlanFor(regionNumber: 8, chapterNumber: 1),
        throwsArgumentError,
      );
      expect(
        sentenceMathPlanFor(regionNumber: 3, chapterNumber: 1).focus,
        SentenceMathFocus.commonUnits,
      );
      expect(
        sentenceMathPlanFor(regionNumber: 4, chapterNumber: 2).focus,
        SentenceMathFocus.unknownGroups,
      );
      expect(
        sentenceMathPlanFor(regionNumber: 6, chapterNumber: 3).focus,
        SentenceMathFocus.dataRelationships,
      );
      expect(
        sentenceMathPlanFor(
          regionNumber: 2,
          chapterNumber: 6,
          sourceStageId: 'r01-c03-s05',
        ).focus,
        SentenceMathFocus.operationOrder,
      );
      expect(
        () => sentenceMathPlanFor(
          regionNumber: 2,
          chapterNumber: 6,
          sourceStageId: 'r03-c01-s05',
        ),
        throwsArgumentError,
      );
      expect(
        () => sentenceMathPlanFor(
          regionNumber: 2,
          chapterNumber: 6,
          sourceStageId: 'not-a-stage',
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'rejects disconnected prose, hidden targets and forged semantic profiles',
    () {
      final stage = initialCampaign.stageById('r01-c01-s03')!;
      final puzzle = r1PuzzlesByStageId[stage.id]!;
      expect(
        _issues(stage.id, _withProblem(puzzle, null)),
        contains(SentenceMathIssue.missingProblem),
      );
      expect(
        _issues(
          stage.id,
          _withProblem(puzzle, _problem(puzzle, targetQuestion: '몇 개일까요?')),
        ),
        contains(SentenceMathIssue.questionMismatch),
      );
      expect(
        _issues(
          stage.id,
          _withProblem(puzzle, _problem(puzzle, givenFacts: const [])),
        ),
        contains(SentenceMathIssue.incompleteInterpretation),
      );
      expect(
        _issues(
          stage.id,
          _withProblem(puzzle, _problem(puzzle, unknownPositionId: 'result')),
        ),
        contains(SentenceMathIssue.semanticProfileMismatch),
      );
      expect(
        _issues(
          stage.id,
          _withProblem(
            puzzle,
            _problem(puzzle, relationshipExplanation: '다른 풀이 관계'),
          ),
        ),
        contains(SentenceMathIssue.relationshipHintMismatch),
      );
    },
  );

  test(
    'numeric equality and a table-like name cannot bypass the real engine',
    () {
      final stage = initialCampaign.stageById('r01-c01-s03')!;
      final puzzle = r1PuzzlesByStageId[stage.id]!;
      // Same value 9, but not the authored quantities or permitted expression AST.
      expect(
        _issues(
          stage.id,
          _withProblem(puzzle, _problem(puzzle, intendedExpression: '9+0')),
        ),
        contains(SentenceMathIssue.intendedExpressionMismatch),
      );
      final unsupported = _withProblem(
        puzzle,
        _problem(puzzle, presentationKind: ProblemPresentationKind.dataTable),
      );
      expect(
        _issues(stage.id, unsupported),
        contains(SentenceMathIssue.unsupportedPresentation),
      );
      final existing = discoveryRuntimeCatalog.resolve(stage);
      final catalog = DiscoveryRuntimeCatalog({
        stage.id: DiscoveryStageRuntime(
          puzzle: unsupported,
          buildBoard: existing.buildBoard,
          refillPieces: existing.refillPieces,
          gemKeys: existing.gemKeys,
        ),
      });
      expect(() => catalog.resolve(stage), throwsStateError);
    },
  );
  test('the permitted AST is checked even when quantities and value match', () {
    final stage = initialCampaign.stageById('r01-c01-s09')!;
    final puzzle = r1PuzzlesByStageId[stage.id]!;
    final tokens = puzzle.tokens;
    final otherGrouping = const EquationEngine().evaluate([
      tokens[2],
      tokens[1],
      tokens[4],
      tokens[3],
      tokens[0],
    ]);
    expect(otherGrouping.value, puzzle.target);
    expect(
      puzzle.allowedExpressionSignatures,
      isNot(contains(otherGrouping.expression!.signature)),
    );
    expect(
      _issues(
        stage.id,
        _withProblem(
          puzzle,
          puzzle.sentenceMath,
          allowedSignatures: {otherGrouping.expression!.signature},
        ),
      ),
      contains(SentenceMathIssue.intendedExpressionMismatch),
    );
  });
  test(
    'a reading budget failure cannot become an apparently ready question',
    () {
      final stage = initialCampaign.stageById('r01-c01-s03')!;
      final puzzle = r1PuzzlesByStageId[stage.id]!;
      final problem = _problem(
        puzzle,
        targetQuestion: List.filled(121, '길').join(),
      );
      expect(
        _issues(stage.id, _withProblem(puzzle, problem)),
        contains(SentenceMathIssue.readingBudgetExceeded),
      );
    },
  );
}

List<SentenceMathIssue> _issues(String stageId, Puzzle puzzle) =>
    const SentenceMathValidator().validate(
      initialCampaign.stageById(stageId)!,
      puzzle,
    );

SentenceMathProblem _problem(
  Puzzle puzzle, {
  List<String>? givenFacts,
  String? targetQuestion,
  String? intendedExpression,
  String? unknownPositionId,
  String? relationshipExplanation,
  ProblemPresentationKind? presentationKind,
}) {
  final original = puzzle.sentenceMath!;
  return SentenceMathProblem(
    givenFacts: givenFacts ?? original.givenFacts,
    targetQuestion: targetQuestion ?? original.targetQuestion,
    relationshipExplanation:
        relationshipExplanation ?? original.relationshipExplanation,
    intendedExpression: intendedExpression ?? original.intendedExpression,
    relationSchemaId: original.relationSchemaId,
    unknownPositionId: unknownPositionId ?? original.unknownPositionId,
    contextFamilyId: original.contextFamilyId,
    representationId: original.representationId,
    presentationKind: presentationKind ?? original.presentationKind,
  );
}

Puzzle _withProblem(
  Puzzle puzzle,
  SentenceMathProblem? problem, {
  Set<ExpressionSignature>? allowedSignatures,
}) => Puzzle(
  id: puzzle.id,
  stageLabel: puzzle.stageLabel,
  concept: puzzle.concept,
  question: puzzle.question,
  target: puzzle.target,
  tokens: puzzle.tokens,
  requiredTokenIds: puzzle.requiredTokenIds,
  allowedExpressionSignatures:
      allowedSignatures ?? puzzle.allowedExpressionSignatures,
  hints: puzzle.hints,
  explanation: puzzle.explanation,
  learningSupport: puzzle.learningSupport,
  visualDescription: puzzle.visualDescription,
  sentenceMath: problem,
);
