enum PuzzleHintKind { observation, relationship, partialExpression }

class PuzzleHintStep {
  const PuzzleHintStep({required this.kind, required this.message})
    : assert(message != '');

  final PuzzleHintKind kind;
  final String message;
}

enum PuzzleMisconceptionCategory {
  incompleteExpression,
  tokenSelection,
  syntax,
  quantityRelationship,
  operationOrder,
}

class PuzzleMisconceptionFeedback {
  const PuzzleMisconceptionFeedback({
    required this.category,
    required this.message,
  }) : assert(message != '');

  final PuzzleMisconceptionCategory category;
  final String message;
}

class PuzzleWorkedSolutionStep {
  const PuzzleWorkedSolutionStep({
    required this.expression,
    required this.explanation,
  }) : assert(expression != ''),
       assert(explanation != '');

  final String expression;
  final String explanation;
}

class PuzzleTransferPrompt {
  const PuzzleTransferPrompt({
    required this.question,
    required this.expectedExpression,
  }) : assert(question != ''),
       assert(expectedExpression != '');

  final String question;
  final String expectedExpression;
}

class PuzzleLearningSupport {
  const PuzzleLearningSupport({
    required this.learningObjective,
    required this.hintSteps,
    required this.misconceptionFeedback,
    required this.workedSolutionSteps,
    required this.transferPrompt,
  }) : assert(learningObjective != '');

  final String learningObjective;
  final List<PuzzleHintStep> hintSteps;
  final List<PuzzleMisconceptionFeedback> misconceptionFeedback;
  final List<PuzzleWorkedSolutionStep> workedSolutionSteps;
  final PuzzleTransferPrompt transferPrompt;

  String? feedbackFor(PuzzleMisconceptionCategory category) {
    for (final feedback in misconceptionFeedback) {
      if (feedback.category == category) {
        return feedback.message;
      }
    }
    return null;
  }

  bool get hasCompletePlayableSupport {
    const requiredHintKinds = [
      PuzzleHintKind.observation,
      PuzzleHintKind.relationship,
      PuzzleHintKind.partialExpression,
    ];
    final hintSequenceIsComplete =
        hintSteps.length == requiredHintKinds.length &&
        List.generate(
          requiredHintKinds.length,
          (index) => hintSteps[index].kind == requiredHintKinds[index],
        ).every((matches) => matches);
    final feedbackKinds = {
      for (final feedback in misconceptionFeedback) feedback.category,
    };
    return learningObjective.trim().isNotEmpty &&
        hintSequenceIsComplete &&
        hintSteps.every((hint) => hint.message.trim().isNotEmpty) &&
        misconceptionFeedback.length ==
            PuzzleMisconceptionCategory.values.length &&
        feedbackKinds.length == PuzzleMisconceptionCategory.values.length &&
        feedbackKinds.containsAll(PuzzleMisconceptionCategory.values) &&
        workedSolutionSteps.length >= 2 &&
        workedSolutionSteps.every(
          (step) =>
              step.expression.trim().isNotEmpty &&
              step.explanation.trim().isNotEmpty,
        ) &&
        transferPrompt.question.trim().isNotEmpty &&
        transferPrompt.expectedExpression.trim().isNotEmpty;
  }
}
