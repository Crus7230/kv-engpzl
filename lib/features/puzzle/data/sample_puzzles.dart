import '../domain/equation_engine.dart';
import '../domain/equation_token.dart';
import '../domain/puzzle.dart';
import '../domain/puzzle_learning_support.dart';
import '../domain/rational.dart';

EquationToken _number(String id, int value) =>
    EquationToken(id: id, label: '$value', kind: EquationTokenKind.number);

EquationToken _operator(String id, String label) =>
    EquationToken(id: id, label: label, kind: EquationTokenKind.operator);

EquationToken _left(String id) =>
    EquationToken(id: id, label: '(', kind: EquationTokenKind.leftParenthesis);

EquationToken _right(String id) =>
    EquationToken(id: id, label: ')', kind: EquationTokenKind.rightParenthesis);

ExpressionSignature _numberSignature(String tokenId) =>
    ExpressionSignature.number(tokenId);

ExpressionSignature _binarySignature(
  String operatorLabel,
  ExpressionSignature left,
  ExpressionSignature right,
) => ExpressionSignature.binary(
  operatorLabel: operatorLabel,
  left: left,
  right: right,
);

final List<Puzzle> samplePuzzles = [
  Puzzle(
    id: 'bundle-add-01',
    stageLabel: '계산의 평원 · 1-1',
    concept: '곱셈 후 덧셈',
    question: '연필이 4자루씩 들어 있는 상자 3개와 낱개 연필 2자루가 있습니다. 연필은 모두 몇 자루일까요?',
    target: Rational(14),
    tokens: [
      _number('p1-n3', 3),
      _operator('p1-plus', '+'),
      _number('p1-d5', 5),
      _number('p1-n4', 4),
      _operator('p1-minus', '-'),
      _number('p1-n2', 2),
      _operator('p1-times', '×'),
    ],
    requiredTokenIds: const {'p1-n4', 'p1-times', 'p1-n3', 'p1-plus', 'p1-n2'},
    allowedExpressionSignatures: {
      _binarySignature(
        '+',
        _binarySignature(
          '×',
          _numberSignature('p1-n4'),
          _numberSignature('p1-n3'),
        ),
        _numberSignature('p1-n2'),
      ),
    },
    hints: const [
      '먼저 상자 안 연필의 수를 구해 보세요.',
      '4자루씩 3상자는 4 × 3으로 나타낼 수 있어요.',
      '상자 속 연필을 구한 뒤 낱개 2자루를 더하세요.',
    ],
    explanation: '4 × 3으로 상자 속 12자루를 구하고, 낱개 2자루를 더하면 14자루입니다.',
    learningSupport: const PuzzleLearningSupport(
      learningObjective: '같은 수의 묶음은 곱셈으로, 따로 있는 수량은 덧셈으로 나타낸다.',
      hintSteps: [
        PuzzleHintStep(
          kind: PuzzleHintKind.observation,
          message: '상자마다 같은 수의 연필이 있고, 낱개 연필은 상자 밖에 따로 있어요.',
        ),
        PuzzleHintStep(
          kind: PuzzleHintKind.relationship,
          message: '4자루씩 3상자는 4를 3번 더하는 것과 같으므로 곱셈으로 나타내요.',
        ),
        PuzzleHintStep(
          kind: PuzzleHintKind.partialExpression,
          message: '먼저 4 × 3을 만들고, 그 뒤에 낱개 2를 더해 보세요.',
        ),
      ],
      misconceptionFeedback: [
        PuzzleMisconceptionFeedback(
          category: PuzzleMisconceptionCategory.incompleteExpression,
          message: '상자 속 연필과 낱개 연필을 모두 나타내는 블록이 필요해요.',
        ),
        PuzzleMisconceptionFeedback(
          category: PuzzleMisconceptionCategory.tokenSelection,
          message: '문장에 나온 4, 3, 2와 곱셈, 덧셈 블록만 한 번씩 사용해 보세요.',
        ),
        PuzzleMisconceptionFeedback(
          category: PuzzleMisconceptionCategory.syntax,
          message: '수와 연산자가 번갈아 오도록 블록의 순서를 확인해 보세요.',
        ),
        PuzzleMisconceptionFeedback(
          category: PuzzleMisconceptionCategory.quantityRelationship,
          message: '4는 한 상자의 연필 수이고 3은 상자 수예요. 문장의 묶음 관계가 식에 그대로 보여야 해요.',
        ),
        PuzzleMisconceptionFeedback(
          category: PuzzleMisconceptionCategory.operationOrder,
          message: '낱개 2자루는 상자 수에 더하지 말고, 4 × 3으로 상자 속 연필을 구한 뒤 더하세요.',
        ),
      ],
      workedSolutionSteps: [
        PuzzleWorkedSolutionStep(
          expression: '4 × 3 = 12',
          explanation: '한 상자에 4자루씩 있는 상자가 3개이므로 상자 속 연필은 12자루예요.',
        ),
        PuzzleWorkedSolutionStep(
          expression: '12 + 2 = 14',
          explanation: '상자 속 12자루에 낱개 2자루를 더하면 모두 14자루예요.',
        ),
      ],
      transferPrompt: PuzzleTransferPrompt(
        question: '한 봉지에 구슬이 5개씩 든 봉지 2개와 낱개 구슬 3개는 어떤 식으로 나타낼까요?',
        expectedExpression: '5×2+3',
      ),
    ),
  ),
  Puzzle(
    id: 'rectangle-perimeter-01',
    stageLabel: '도형의 섬 · 1-2',
    concept: '직사각형의 둘레',
    question: '가로 7cm, 세로 5cm인 직사각형의 둘레를 구하는 식을 완성하세요.',
    target: Rational(24),
    tokens: [
      _number('p2-seven', 7),
      _right('p2-right'),
      _operator('p2-times', '×'),
      _number('p2-d12', 12),
      _left('p2-left'),
      _number('p2-two', 2),
      _operator('p2-plus', '+'),
      _number('p2-five', 5),
      _operator('p2-minus', '-'),
    ],
    requiredTokenIds: const {
      'p2-two',
      'p2-times',
      'p2-left',
      'p2-seven',
      'p2-plus',
      'p2-five',
      'p2-right',
    },
    allowedExpressionSignatures: {
      _binarySignature(
        '×',
        _numberSignature('p2-two'),
        _binarySignature(
          '+',
          _numberSignature('p2-seven'),
          _numberSignature('p2-five'),
        ),
      ),
    },
    hints: const [
      '직사각형은 가로와 세로가 각각 두 변씩 있어요.',
      '먼저 가로와 세로의 길이를 더해 보세요.',
      '둘레는 2 × (가로 + 세로)로 구할 수 있어요.',
    ],
    explanation: '가로와 세로의 합 12cm가 두 번 있으므로 2 × (7 + 5) = 24cm입니다.',
  ),
  Puzzle(
    id: 'square-area-01',
    stageLabel: '도형의 섬 · 1-3',
    concept: '정사각형의 넓이',
    question: '한 변의 길이가 6cm인 정사각형의 넓이를 구하는 식을 만드세요.',
    target: Rational(36),
    tokens: [
      _number('p3-six-a', 6),
      _operator('p3-plus', '+'),
      _number('p3-twelve', 12),
      _operator('p3-times', '×'),
      _number('p3-six-b', 6),
    ],
    requiredTokenIds: const {'p3-six-a', 'p3-times', 'p3-six-b'},
    allowedExpressionSignatures: {
      _binarySignature(
        '×',
        _numberSignature('p3-six-a'),
        _numberSignature('p3-six-b'),
      ),
    },
    hints: const [
      '넓이는 가로 × 세로로 구해요.',
      '정사각형은 가로와 세로의 길이가 같아요.',
      '같은 6 블록 두 개를 모두 사용하세요.',
    ],
    explanation: '정사각형의 가로와 세로가 모두 6cm이므로 6 × 6 = 36cm²입니다.',
  ),
  Puzzle(
    id: 'time-conversion-01',
    stageLabel: '측정의 협곡 · 1-4',
    concept: '시간 단위 바꾸기',
    question: '2시간 35분을 모두 분으로 나타내는 식을 완성하세요.',
    target: Rational(155),
    tokens: [
      _number('p4-thirty-five', 35),
      _operator('p4-plus', '+'),
      _number('p4-sixty', 60),
      _operator('p4-divide', '÷'),
      _number('p4-two', 2),
      _operator('p4-times', '×'),
    ],
    requiredTokenIds: const {
      'p4-two',
      'p4-times',
      'p4-sixty',
      'p4-plus',
      'p4-thirty-five',
    },
    allowedExpressionSignatures: {
      _binarySignature(
        '+',
        _binarySignature(
          '×',
          _numberSignature('p4-two'),
          _numberSignature('p4-sixty'),
        ),
        _numberSignature('p4-thirty-five'),
      ),
    },
    hints: const [
      '1시간은 60분이에요.',
      '2시간을 분으로 바꾸려면 2 × 60을 계산해요.',
      '바꾼 120분에 35분을 더하세요.',
    ],
    explanation: '2시간은 2 × 60 = 120분이고, 여기에 35분을 더하면 155분입니다.',
  ),
  Puzzle(
    id: 'sum-difference-01',
    stageLabel: '관계의 산맥 · 1-5',
    concept: '합과 차로 큰 수 찾기',
    question: '두 수의 합이 32이고 차가 8입니다. 큰 수를 구하는 식을 완성하세요.',
    target: Rational(20),
    tokens: [
      _operator('p5-divide', '÷'),
      _number('p5-eight', 8),
      _left('p5-left'),
      _number('p5-two', 2),
      _operator('p5-minus', '-'),
      _number('p5-thirty-two', 32),
      _right('p5-right'),
      _operator('p5-plus', '+'),
    ],
    requiredTokenIds: const {
      'p5-left',
      'p5-thirty-two',
      'p5-plus',
      'p5-eight',
      'p5-right',
      'p5-divide',
      'p5-two',
    },
    allowedExpressionSignatures: {
      _binarySignature(
        '÷',
        _binarySignature(
          '+',
          _numberSignature('p5-thirty-two'),
          _numberSignature('p5-eight'),
        ),
        _numberSignature('p5-two'),
      ),
    },
    hints: const [
      '합과 차를 더하면 큰 수가 두 번 포함돼요.',
      '먼저 32 + 8을 괄호로 묶어 보세요.',
      '(합 + 차) ÷ 2로 큰 수를 구할 수 있어요.',
    ],
    explanation: '(32 + 8) ÷ 2 = 20이므로 큰 수는 20입니다.',
  ),
];
