import '../../puzzle/domain/authored_expression_checker.dart';
import '../../puzzle/domain/equation_token.dart';
import '../../puzzle/domain/puzzle.dart';
import '../../puzzle/domain/puzzle_learning_support.dart';
import '../../puzzle/domain/sentence_math_problem.dart';
import 'campaign_models.dart';
import 'sentence_math_plan.dart';

enum SentenceMathIssue {
  missingPlan,
  invalidPlanBinding,
  missingProblem,
  incompleteInterpretation,
  questionMismatch,
  readingBudgetExceeded,
  semanticProfileMismatch,
  relationshipHintMismatch,
  intendedExpressionMismatch,
  unsupportedPresentation,
}

/// Mechanical authoring checks only. These cannot certify that a natural-
/// language relationship is unambiguous or educationally appropriate.
class SentenceMathValidator {
  const SentenceMathValidator();

  List<SentenceMathIssue> validatePlan(StageDefinition stage) {
    final location = RegExp(
      r'^r(\d{2})-c(\d{2})-s(\d{2})$',
    ).firstMatch(stage.id);
    if (location == null) return const []; // Development/legacy fixtures.
    final plan = stage.sentenceMathPlan;
    if (plan == null) return const [SentenceMathIssue.missingPlan];
    if (plan.regionNumber != int.parse(location.group(1)!) ||
        plan.regionNumber < 1 ||
        plan.regionNumber > 7 ||
        plan.chapterNumber < 1 ||
        plan.chapterNumber > 6 ||
        plan.chapterNumber != int.parse(location.group(2)!) ||
        plan.phase !=
            (switch (plan.chapterNumber) {
              4 => SentenceMathChapterPhase.retrieval,
              5 => SentenceMathChapterPhase.familiarMathNewBoard,
              6 => SentenceMathChapterPhase.integratedTransfer,
              _ => SentenceMathChapterPhase.conceptDevelopment,
            }) ||
        (plan.chapterNumber >= 4) != (plan.sourceStageId != null) ||
        plan.sourceStageId != stage.recurrencePlan?.sourceStageId ||
        plan.authoringGoal.trim().isEmpty ||
        plan.bridgeGoal.trim().isEmpty ||
        plan.maximumQuestionCharacters < 1 ||
        plan.maximumFactSentences < 1) {
      return const [SentenceMathIssue.invalidPlanBinding];
    }
    return const [];
  }

  List<SentenceMathIssue> validate(StageDefinition stage, Puzzle puzzle) {
    final issues = [...validatePlan(stage)];
    final plan = stage.sentenceMathPlan;
    if (plan == null) return issues;
    final problem = puzzle.sentenceMath;
    if (problem == null) return [...issues, SentenceMathIssue.missingProblem];
    if (problem.givenFacts.isEmpty ||
        problem.givenFacts.any((fact) => fact.trim().isEmpty) ||
        problem.targetQuestion.trim().isEmpty ||
        problem.relationshipExplanation.trim().isEmpty) {
      issues.add(SentenceMathIssue.incompleteInterpretation);
    }
    if (problem.fullText != puzzle.question) {
      issues.add(SentenceMathIssue.questionMismatch);
    }
    if (problem.fullText.length > plan.maximumQuestionCharacters ||
        problem.givenFacts.length > plan.maximumFactSentences) {
      issues.add(SentenceMathIssue.readingBudgetExceeded);
    }
    final profile = stage.variantProfile;
    if (problem.relationSchemaId != profile.relationSchemaId ||
        problem.unknownPositionId != profile.unknownPositionId ||
        problem.contextFamilyId != profile.contextFamilyId ||
        problem.representationId != profile.representationId) {
      issues.add(SentenceMathIssue.semanticProfileMismatch);
    }
    final relationshipHints =
        puzzle.learningSupport?.hintSteps
            .where((hint) => hint.kind == PuzzleHintKind.relationship)
            .toList() ??
        const <PuzzleHintStep>[];
    if (relationshipHints.length != 1 ||
        relationshipHints.single.message != problem.relationshipExplanation) {
      issues.add(SentenceMathIssue.relationshipHintMismatch);
    }
    if (!_matchesIntendedExpression(stage, puzzle, problem)) {
      issues.add(SentenceMathIssue.intendedExpressionMismatch);
    }
    if (stage.hasAuthoredPuzzle &&
        !SentenceMathProblem.supportedPresentations.contains(
          problem.presentationKind,
        )) {
      issues.add(SentenceMathIssue.unsupportedPresentation);
    }
    return List.unmodifiable(issues);
  }

  bool _matchesIntendedExpression(
    StageDefinition stage,
    Puzzle puzzle,
    SentenceMathProblem problem,
  ) {
    String normalized(String expression) => expression
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('*', '×')
        .replaceAll('/', '÷');
    final source = normalized(problem.intendedExpression);
    final check = const AuthoredExpressionChecker().evaluate(source);
    if (!check.isValid ||
        check.value != puzzle.target ||
        source != normalized(stage.answerExpression))
      return false;

    // Rebind expression occurrences to unique required token instances, then
    // use the real puzzle validator. Equal numeric values alone do not pass.
    final remaining = puzzle.tokens
        .where((token) => puzzle.requiredTokenIds.contains(token.id))
        .toList();
    final ordered = <EquationToken>[];
    for (final match in RegExp(r'\d+|[+\-×÷()]').allMatches(source)) {
      final index = remaining.indexWhere(
        (token) => token.label == match.group(0),
      );
      if (index < 0) return false;
      ordered.add(remaining.removeAt(index));
    }
    return remaining.isEmpty &&
        const PuzzleValidator().validate(puzzle, ordered).isCorrect;
  }
}
