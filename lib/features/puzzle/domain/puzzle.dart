import 'equation_engine.dart';
import 'equation_token.dart';
import 'puzzle_learning_support.dart';
import 'rational.dart';

class Puzzle {
  const Puzzle({
    required this.id,
    required this.stageLabel,
    required this.concept,
    required this.question,
    required this.target,
    required this.tokens,
    required this.requiredTokenIds,
    required this.allowedExpressionSignatures,
    required this.hints,
    required this.explanation,
    this.learningSupport,
    this.visualDescription = '',
  });

  final String id;
  final String stageLabel;
  final String concept;
  final String question;
  final Rational target;
  final List<EquationToken> tokens;
  final Set<String> requiredTokenIds;
  final Set<ExpressionSignature> allowedExpressionSignatures;
  final List<String> hints;
  final String explanation;
  final PuzzleLearningSupport? learningSupport;

  /// Text equivalent of the quantities/layout; no illustration is required
  /// to solve an authored problem.
  final String visualDescription;

  List<String> get effectiveHints => learningSupport == null
      ? hints
      : List.unmodifiable(
          learningSupport!.hintSteps.map((hint) => hint.message),
        );
}

enum PuzzleValidationReason {
  empty,
  missingRequiredToken,
  duplicatedToken,
  unknownToken,
  distractorUsed,
  invalidSyntax,
  wrongValue,
  correct,
}

class PuzzleValidationResult {
  const PuzzleValidationResult(
    this.reason, {
    this.evaluation,
    this.isStructureMismatch = false,
  });

  final PuzzleValidationReason reason;
  final EquationEvaluation? evaluation;
  final bool isStructureMismatch;

  bool get isCorrect => reason == PuzzleValidationReason.correct;
}

class PuzzleValidator {
  const PuzzleValidator({this.engine = const EquationEngine()});

  final EquationEngine engine;

  PuzzleValidationResult validate(
    Puzzle puzzle,
    List<EquationToken> expression,
  ) {
    if (expression.isEmpty) {
      return const PuzzleValidationResult(PuzzleValidationReason.empty);
    }

    final availableTokens = {
      for (final token in puzzle.tokens) token.id: token,
    };
    final usedIds = expression.map((token) => token.id).toList();
    if (expression.any((token) {
      final original = availableTokens[token.id];
      return original == null ||
          original.label != token.label ||
          original.kind != token.kind;
    })) {
      return const PuzzleValidationResult(PuzzleValidationReason.unknownToken);
    }
    if (usedIds.toSet().length != usedIds.length) {
      return const PuzzleValidationResult(
        PuzzleValidationReason.duplicatedToken,
      );
    }
    if (usedIds.any((id) => !puzzle.requiredTokenIds.contains(id))) {
      return const PuzzleValidationResult(
        PuzzleValidationReason.distractorUsed,
      );
    }
    if (!usedIds.toSet().containsAll(puzzle.requiredTokenIds)) {
      return const PuzzleValidationResult(
        PuzzleValidationReason.missingRequiredToken,
      );
    }

    final evaluation = engine.evaluate(expression);
    if (!evaluation.isSuccess) {
      return PuzzleValidationResult(
        PuzzleValidationReason.invalidSyntax,
        evaluation: evaluation,
      );
    }
    if (evaluation.value != puzzle.target) {
      return PuzzleValidationResult(
        PuzzleValidationReason.wrongValue,
        evaluation: evaluation,
      );
    }
    if (!puzzle.allowedExpressionSignatures.contains(
      evaluation.expression!.signature,
    )) {
      return PuzzleValidationResult(
        PuzzleValidationReason.wrongValue,
        evaluation: evaluation,
        isStructureMismatch: true,
      );
    }
    return PuzzleValidationResult(
      PuzzleValidationReason.correct,
      evaluation: evaluation,
    );
  }
}
