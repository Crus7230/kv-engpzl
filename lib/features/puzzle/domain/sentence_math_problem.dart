/// A renderer is a capability, not a label in a semantic fingerprint. A text
/// record called a "table" does not mean that a table renderer exists.
enum ProblemPresentationKind {
  prose,
  textRecord,
  sequence,
  inputOutputTable,
  measurementDiagram,
  balanceDiagram,
  geometryDiagram,
  dataTable,
}

/// Authored interpretation of a sentence problem. This is not an NLP solver:
/// editors still review whether the stated relationship follows from the text.
/// The relationship and intended expression stay hidden until a hint/result.
class SentenceMathProblem {
  SentenceMathProblem({
    required Iterable<String> givenFacts,
    required this.targetQuestion,
    required this.relationshipExplanation,
    required this.intendedExpression,
    required this.relationSchemaId,
    required this.unknownPositionId,
    required this.contextFamilyId,
    required this.representationId,
    required this.presentationKind,
  }) : givenFacts = List.unmodifiable(givenFacts);

  /// Compatibility adapter for already edited R1 prose. New content may supply
  /// the facts/target directly instead of relying on sentence punctuation.
  factory SentenceMathProblem.fromLegacyQuestion({
    required String question,
    required String relationshipExplanation,
    required String intendedExpression,
    required String relationSchemaId,
    required String unknownPositionId,
    required String contextFamilyId,
    required String representationId,
    required ProblemPresentationKind presentationKind,
  }) {
    final sentences = question.split(RegExp(r'(?<=\.)\s+'));
    return SentenceMathProblem(
      givenFacts: sentences.take(sentences.length - 1),
      targetQuestion: sentences.last,
      relationshipExplanation: relationshipExplanation,
      intendedExpression: intendedExpression,
      relationSchemaId: relationSchemaId,
      unknownPositionId: unknownPositionId,
      contextFamilyId: contextFamilyId,
      representationId: representationId,
      presentationKind: presentationKind,
    );
  }

  final List<String> givenFacts;
  final String targetQuestion;
  final String relationshipExplanation;
  final String intendedExpression;
  final String relationSchemaId;
  final String unknownPositionId;
  final String contextFamilyId;
  final String representationId;
  final ProblemPresentationKind presentationKind;

  String get fullText => [...givenFacts, targetQuestion].join(' ');

  static const supportedPresentations = {
    ProblemPresentationKind.prose,
    ProblemPresentationKind.textRecord,
  };
}
