import 'dart:io';

import '../lib/features/puzzle/data/sample_puzzles.dart';
import '../lib/features/puzzle/domain/equation_engine.dart';
import '../lib/features/puzzle/domain/equation_token.dart';
import '../lib/features/puzzle/domain/puzzle.dart';
import '../lib/features/puzzle/domain/rational.dart';

void main() {
  const engine = EquationEngine();
  const validator = PuzzleValidator();

  final duplicateNumberExpression = [
    _number('six-a', 6),
    _operator('times', '×'),
    _number('six-b', 6),
  ];
  _expect(
    engine.evaluate(duplicateNumberExpression).value == Rational(36),
    'duplicate display-value tokens should evaluate independently',
  );

  final parenthesizedExpression = [
    _left('left'),
    _number('thirty-two', 32),
    _operator('plus', '+'),
    _number('eight', 8),
    _right('right'),
    _operator('divide', '÷'),
    _number('two', 2),
  ];
  _expect(
    engine.evaluate(parenthesizedExpression).value == Rational(20),
    'parentheses and division should preserve exact values',
  );

  final adjacentNumbers = [_number('a', 2), _number('b', 3)];
  _expect(
    engine.evaluate(adjacentNumbers).error ==
        EquationErrorCode.expectedOperator,
    'adjacent numbers must not be accepted as a complete expression',
  );

  final divisionByZero = [
    _number('eight', 8),
    _operator('divide', '÷'),
    _number('zero', 0),
  ];
  _expect(
    engine.evaluate(divisionByZero).error == EquationErrorCode.divisionByZero,
    'division by zero should be reported',
  );

  for (var index = 0; index < samplePuzzles.length; index += 1) {
    final puzzle = samplePuzzles[index];
    final expression = _tokensById(puzzle, _sampleSolutionTokenIds[index]);
    _expect(
      validator.validate(puzzle, expression).isCorrect,
      '${puzzle.id} should accept its intended expression',
    );
  }

  final firstPuzzle = samplePuzzles.first;
  final commutativeSwap = _tokensById(firstPuzzle, const [
    'p1-n2',
    'p1-plus',
    'p1-n3',
    'p1-times',
    'p1-n4',
  ]);
  _expect(
    validator.validate(firstPuzzle, commutativeSwap).isCorrect,
    'direct commutative swaps should preserve the accepted AST signature',
  );

  final a = ExpressionSignature.number('a');
  final b = ExpressionSignature.number('b');
  final c = ExpressionSignature.number('c');
  final leftGrouped = ExpressionSignature.binary(
    operatorLabel: '+',
    left: ExpressionSignature.binary(operatorLabel: '+', left: a, right: b),
    right: c,
  );
  final rightGrouped = ExpressionSignature.binary(
    operatorLabel: '+',
    left: a,
    right: ExpressionSignature.binary(operatorLabel: '+', left: b, right: c),
  );
  _expect(
    leftGrouped != rightGrouped,
    'commutative normalization must not flatten associative grouping',
  );

  final structurePuzzle = _structurePuzzle();
  final structureById = {
    for (final token in structurePuzzle.tokens) token.id: token,
  };
  final wrongStructure = [
    structureById['eight']!,
    structureById['plus']!,
    structureById['added-three']!,
    structureById['minus']!,
    structureById['removed-three']!,
  ];
  final wrongStructureResult = validator.validate(
    structurePuzzle,
    wrongStructure,
  );
  _expect(
    wrongStructureResult.evaluation?.value == Rational(8) &&
        !wrongStructureResult.isCorrect &&
        wrongStructureResult.isStructureMismatch,
    'a different AST with the target value must be rejected',
  );

  final intended = _tokensById(firstPuzzle, _sampleSolutionTokenIds.first);
  final changedLabel = [...intended]
    ..[0] = const EquationToken(
      id: 'p1-n4',
      label: '14',
      kind: EquationTokenKind.number,
    );
  final changedKind = [...intended]
    ..[0] = const EquationToken(
      id: 'p1-n4',
      label: '4',
      kind: EquationTokenKind.operator,
    );
  _expect(
    validator.validate(firstPuzzle, changedLabel).reason ==
        PuzzleValidationReason.unknownToken,
    'a known token ID with a modified label must be rejected',
  );
  _expect(
    validator.validate(firstPuzzle, changedKind).reason ==
        PuzzleValidationReason.unknownToken,
    'a known token ID with a modified kind must be rejected',
  );
  final answerWithDistractor = _tokensById(firstPuzzle, const [
    'p1-n4',
    'p1-times',
    'p1-n3',
    'p1-plus',
    'p1-d5',
  ]);
  _expect(
    validator.validate(firstPuzzle, answerWithDistractor).reason ==
        PuzzleValidationReason.distractorUsed,
    'a discovered distractor should be identified before the missing token',
  );
  _expect(
    samplePuzzles[2].tokens.where((token) => token.label == '6').length == 2,
    'the square-area sample should retain both 6 tokens',
  );

  stdout.writeln('Equation engine verification passed.');
}

const List<List<String>> _sampleSolutionTokenIds = [
  ['p1-n4', 'p1-times', 'p1-n3', 'p1-plus', 'p1-n2'],
  [
    'p2-two',
    'p2-times',
    'p2-left',
    'p2-seven',
    'p2-plus',
    'p2-five',
    'p2-right',
  ],
  ['p3-six-a', 'p3-times', 'p3-six-b'],
  ['p4-two', 'p4-times', 'p4-sixty', 'p4-plus', 'p4-thirty-five'],
  [
    'p5-left',
    'p5-thirty-two',
    'p5-plus',
    'p5-eight',
    'p5-right',
    'p5-divide',
    'p5-two',
  ],
];

List<EquationToken> _tokensById(Puzzle puzzle, List<String> ids) {
  final byId = {for (final token in puzzle.tokens) token.id: token};
  return [for (final id in ids) byId[id]!];
}

Puzzle _structurePuzzle() {
  const tokens = [
    EquationToken(id: 'eight', label: '8', kind: EquationTokenKind.number),
    EquationToken(
      id: 'removed-three',
      label: '3',
      kind: EquationTokenKind.number,
    ),
    EquationToken(
      id: 'added-three',
      label: '3',
      kind: EquationTokenKind.number,
    ),
    EquationToken(id: 'minus', label: '-', kind: EquationTokenKind.operator),
    EquationToken(id: 'plus', label: '+', kind: EquationTokenKind.operator),
  ];
  return Puzzle(
    id: 'structure-check',
    stageLabel: 'test',
    concept: 'test',
    question: 'test',
    target: Rational(8),
    tokens: tokens,
    requiredTokenIds: const {
      'eight',
      'removed-three',
      'added-three',
      'minus',
      'plus',
    },
    allowedExpressionSignatures: {
      ExpressionSignature.binary(
        operatorLabel: '+',
        left: ExpressionSignature.binary(
          operatorLabel: '-',
          left: ExpressionSignature.number('eight'),
          right: ExpressionSignature.number('removed-three'),
        ),
        right: ExpressionSignature.number('added-three'),
      ),
    },
    hints: const [],
    explanation: 'test',
  );
}

EquationToken _number(String id, int value) =>
    EquationToken(id: id, label: '$value', kind: EquationTokenKind.number);

EquationToken _operator(String id, String label) =>
    EquationToken(id: id, label: label, kind: EquationTokenKind.operator);

EquationToken _left(String id) =>
    EquationToken(id: id, label: '(', kind: EquationTokenKind.leftParenthesis);

EquationToken _right(String id) =>
    EquationToken(id: id, label: ')', kind: EquationTokenKind.rightParenthesis);

void _expect(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}
