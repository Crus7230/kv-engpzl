import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/puzzle/data/sample_puzzles.dart';
import 'package:kvm/features/puzzle/domain/equation_engine.dart';
import 'package:kvm/features/puzzle/domain/equation_token.dart';
import 'package:kvm/features/puzzle/domain/puzzle.dart';
import 'package:kvm/features/puzzle/domain/rational.dart';

void main() {
  const engine = EquationEngine();

  test('preserves duplicate display-value tokens', () {
    final result = engine.evaluate([
      _number('six-a', 6),
      _operator('times', '×'),
      _number('six-b', 6),
    ]);

    expect(result.value, Rational(36));
  });

  test(
    'rejects adjacent numbers instead of returning the final stack item',
    () {
      final result = engine.evaluate([
        _number('first', 2),
        _number('second', 3),
      ]);

      expect(result.error, EquationErrorCode.expectedOperator);
    },
  );

  test('evaluates division as an exact rational value', () {
    final result = engine.evaluate([
      _number('one', 1),
      _operator('divide', '÷'),
      _number('two', 2),
      _operator('plus', '+'),
      _number('quarter', 1),
      _operator('divide-2', '÷'),
      _number('four', 4),
    ]);

    expect(result.value, Rational(3, 4));
  });

  test('accepts the intended expression for every fixed sample', () {
    const validator = PuzzleValidator();

    for (var index = 0; index < samplePuzzles.length; index += 1) {
      final puzzle = samplePuzzles[index];
      final expression = _tokensById(puzzle, _sampleSolutionTokenIds[index]);

      expect(
        validator.validate(puzzle, expression).isCorrect,
        isTrue,
        reason: 'Expected ${puzzle.id} to accept its intended expression.',
      );
    }
  });

  test('accepts direct commutative swaps without flattening the AST', () {
    const validator = PuzzleValidator();
    final puzzle = samplePuzzles.first;
    final swappedExpression = _tokensById(puzzle, const [
      'p1-n2',
      'p1-plus',
      'p1-n3',
      'p1-times',
      'p1-n4',
    ]);
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

    expect(validator.validate(puzzle, swappedExpression).isCorrect, isTrue);
    expect(leftGrouped, isNot(equals(rightGrouped)));
  });

  test('rejects a different AST that happens to have the target value', () {
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
    final puzzle = Puzzle(
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
    final byId = {for (final token in tokens) token.id: token};
    final wrongStructure = [
      byId['eight']!,
      byId['plus']!,
      byId['added-three']!,
      byId['minus']!,
      byId['removed-three']!,
    ];

    final result = const PuzzleValidator().validate(puzzle, wrongStructure);

    expect(result.evaluation?.value, Rational(8));
    expect(result.reason, PuzzleValidationReason.wrongValue);
    expect(result.isStructureMismatch, isTrue);
  });

  test('rejects tokens whose known ID has a modified label or kind', () {
    const validator = PuzzleValidator();
    final puzzle = samplePuzzles.first;
    final intended = _tokensById(puzzle, _sampleSolutionTokenIds.first);
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

    expect(
      validator.validate(puzzle, changedLabel).reason,
      PuzzleValidationReason.unknownToken,
    );
    expect(
      validator.validate(puzzle, changedKind).reason,
      PuzzleValidationReason.unknownToken,
    );
  });
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

EquationToken _number(String id, int value) =>
    EquationToken(id: id, label: '$value', kind: EquationTokenKind.number);

EquationToken _operator(String id, String label) =>
    EquationToken(id: id, label: label, kind: EquationTokenKind.operator);
