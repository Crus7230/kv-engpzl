import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../puzzle/domain/puzzle_learning_support.dart';
import '../../puzzle/domain/sentence_math_problem.dart';

/// Presentation boundary for the discovery puzzle screen.
///
/// The production match-3 domain can be connected through an adapter without
/// making the screen depend on a concrete board engine.
abstract interface class DiscoveryPuzzleViewModel implements Listenable {
  String get stageLabel;
  String get difficultyLabel;
  String get concept;
  String get question;
  SentenceMathProblem? get sentenceMath;
  String get visualDescription;
  String get learningObjective;
  List<PuzzleWorkedSolutionStep> get workedSolutionSteps;
  PuzzleTransferPrompt get transferPrompt;
  int get movesLeft;
  int get score;
  int get boardRows;
  int get boardColumns;
  List<DiscoveryGemCell> get boardCells;
  int? get selectedCellIndex;
  int get requiredBlockCount;
  List<DiscoveryEquationBlock> get discoveredBlocks;
  List<DiscoveryEquationBlock> get answerBlocks;
  String get feedbackMessage;
  DiscoveryFeedbackTone get feedbackTone;
  bool get canCheckAnswer;
  bool get canRevealHint;
  bool get isAnswerCorrect;

  void selectGem(int index);
  void addBlockToAnswer(String blockId);
  void removeBlockFromAnswer(String blockId);
  void revealHint();
  void resetRound();
  void checkAnswer();
}

abstract interface class DiscoveryCompletionHandler {
  void continueToResult();
}

/// Hiding presentation must never undo recorded learning assistance.
abstract interface class DiscoveryHintVisibility {
  bool get isHintVisible;
  void hideHint();
}

abstract interface class DiscoveryObjectiveSource {
  List<DiscoveryObjectiveStatus> get discoveryObjectives;
}

class DiscoveryObjectiveStatus {
  const DiscoveryObjectiveStatus({
    required this.label,
    required this.current,
    required this.goal,
  });
  final String label;
  final int current;
  final int goal;
  bool get isCompleted => current >= goal;
}

enum DiscoveryGemKind { berry, ocean, citrus, grape, leaf, sun }

enum DiscoveryLinePowerKind { row, column, burst, color }

class DiscoveryGemCell {
  const DiscoveryGemCell({
    required this.id,
    required this.kind,
    this.sealKind,
    this.sealLayers = 0,
    this.linePowerKind,
    this.blockerLayers = 0,
    this.iceLayers = 0,
    this.fragmentLabel,
  });

  final String id;
  final DiscoveryGemKind kind;
  final DiscoverySealKind? sealKind;
  final int sealLayers;
  final DiscoveryLinePowerKind? linePowerKind;
  final int blockerLayers;
  final int iceLayers;
  final String? fragmentLabel;
}

enum DiscoverySealKind { number, operatorSymbol, parenthesis }

enum DiscoveryEquationBlockKind { number, operatorSymbol, parenthesis }

class DiscoveryEquationBlock {
  const DiscoveryEquationBlock({
    required this.id,
    required this.label,
    required this.kind,
  });

  final String id;
  final String label;
  final DiscoveryEquationBlockKind kind;
}

enum DiscoveryFeedbackTone { neutral, reward, warning, success }

/// Local interaction model used only until the match-3 domain adapter is
/// connected. An adjacent swap intentionally simulates one successful match.
class DemoDiscoveryPuzzleViewModel extends ChangeNotifier
    implements DiscoveryPuzzleViewModel, DiscoveryHintVisibility {
  DemoDiscoveryPuzzleViewModel() {
    _boardCellsView = UnmodifiableListView(_boardCells);
    _discoveredBlocksView = UnmodifiableListView(_discoveredBlocks);
    _answerBlocksView = UnmodifiableListView(_answerBlocks);
    _resetBoard();
    _discoveredBlocks.addAll(_rewardSequence.take(2));
  }

  static const List<DiscoveryEquationBlock> _rewardSequence = [
    DiscoveryEquationBlock(
      id: 'reward-4',
      label: '4',
      kind: DiscoveryEquationBlockKind.number,
    ),
    DiscoveryEquationBlock(
      id: 'reward-multiply',
      label: '×',
      kind: DiscoveryEquationBlockKind.operatorSymbol,
    ),
    DiscoveryEquationBlock(
      id: 'reward-3',
      label: '3',
      kind: DiscoveryEquationBlockKind.number,
    ),
    DiscoveryEquationBlock(
      id: 'reward-plus',
      label: '+',
      kind: DiscoveryEquationBlockKind.operatorSymbol,
    ),
    DiscoveryEquationBlock(
      id: 'reward-2',
      label: '2',
      kind: DiscoveryEquationBlockKind.number,
    ),
  ];

  final List<DiscoveryGemCell> _boardCells = [];
  final List<DiscoveryEquationBlock> _discoveredBlocks = [];
  final List<DiscoveryEquationBlock> _answerBlocks = [];
  late final UnmodifiableListView<DiscoveryGemCell> _boardCellsView;
  late final UnmodifiableListView<DiscoveryEquationBlock> _discoveredBlocksView;
  late final UnmodifiableListView<DiscoveryEquationBlock> _answerBlocksView;
  int? _selectedCellIndex;
  int _movesLeft = 18;
  int _score = 1240;
  String _feedbackMessage = '인접한 보석을 바꿔 수식 블록을 발굴하세요.';
  DiscoveryFeedbackTone _feedbackTone = DiscoveryFeedbackTone.neutral;
  bool _isAnswerCorrect = false;
  int _hintLevel = 0;

  @override
  String get stageLabel => '수정 협곡 1-3';

  @override
  SentenceMathProblem? get sentenceMath => null;

  @override
  String get difficultyLabel => '수학 2 · 퍼즐 1';

  @override
  String get concept => '곱셈과 덧셈';

  @override
  String get question =>
      '한 봉지에 사탕이 3개씩 있습니다. 4봉지와 낱개 2개에는 '
      '모두 몇 개가 있을까요?';

  @override
  String get learningObjective => '같은 수의 묶음은 곱셈으로, 따로 있는 수량은 덧셈으로 나타낸다.';

  @override
  String get visualDescription => question;

  @override
  List<PuzzleWorkedSolutionStep> get workedSolutionSteps => const [
    PuzzleWorkedSolutionStep(
      expression: '4 × 3 = 12',
      explanation: '3개씩 든 봉지가 4개이므로 봉지 속 사탕은 12개예요.',
    ),
    PuzzleWorkedSolutionStep(
      expression: '12 + 2 = 14',
      explanation: '봉지 속 12개에 낱개 2개를 더하면 모두 14개예요.',
    ),
  ];

  @override
  PuzzleTransferPrompt get transferPrompt => const PuzzleTransferPrompt(
    question: '한 상자에 공이 5개씩 든 상자 2개와 낱개 공 3개는 어떤 식으로 나타낼까요?',
    expectedExpression: '2×5+3',
  );

  @override
  int get movesLeft => _movesLeft;

  @override
  int get score => _score;

  @override
  int get boardRows => 6;

  @override
  int get boardColumns => 6;

  @override
  List<DiscoveryGemCell> get boardCells => _boardCellsView;

  @override
  int? get selectedCellIndex => _selectedCellIndex;

  @override
  int get requiredBlockCount => _rewardSequence.length;

  @override
  List<DiscoveryEquationBlock> get discoveredBlocks => _discoveredBlocksView;

  @override
  List<DiscoveryEquationBlock> get answerBlocks => _answerBlocksView;

  @override
  String get feedbackMessage => _feedbackMessage;

  @override
  DiscoveryFeedbackTone get feedbackTone => _feedbackTone;

  @override
  bool get canCheckAnswer => _answerBlocks.isNotEmpty && !_isAnswerCorrect;

  @override
  bool get canRevealHint => !_isAnswerCorrect;

  @override
  bool get isHintVisible => _feedbackMessage.startsWith('힌트:');

  @override
  void hideHint() {
    if (!isHintVisible) return;
    _feedbackMessage = '인접한 보석을 바꿔 수식 블록을 발굴하세요.';
    _feedbackTone = DiscoveryFeedbackTone.neutral;
    notifyListeners();
  }

  @override
  bool get isAnswerCorrect => _isAnswerCorrect;

  @override
  void selectGem(int index) {
    if (_movesLeft <= 0 || index < 0 || index >= _boardCells.length) {
      return;
    }

    final selected = _selectedCellIndex;
    if (selected == null) {
      _selectedCellIndex = index;
      _feedbackMessage = '바꿀 인접 보석을 하나 더 선택하세요.';
      _feedbackTone = DiscoveryFeedbackTone.neutral;
      notifyListeners();
      return;
    }
    if (selected == index) {
      _selectedCellIndex = null;
      notifyListeners();
      return;
    }
    if (!_areAdjacent(selected, index)) {
      _selectedCellIndex = index;
      _feedbackMessage = '가로나 세로로 맞닿은 보석만 바꿀 수 있어요.';
      _feedbackTone = DiscoveryFeedbackTone.warning;
      notifyListeners();
      return;
    }

    final first = _boardCells[selected];
    _boardCells[selected] = _boardCells[index];
    _boardCells[index] = first;
    _selectedCellIndex = null;
    _movesLeft -= 1;
    _score += 180;
    if (_discoveredBlocks.length < _rewardSequence.length) {
      final reward = _rewardSequence[_discoveredBlocks.length];
      _discoveredBlocks.add(reward);
      _feedbackMessage = '${reward.label} 블록을 발굴했어요!';
      _feedbackTone = DiscoveryFeedbackTone.reward;
    } else {
      _feedbackMessage = '매치 성공! 이제 획득한 블록으로 식을 만들어 보세요.';
      _feedbackTone = DiscoveryFeedbackTone.reward;
    }
    notifyListeners();
  }

  @override
  void addBlockToAnswer(String blockId) {
    if (_isAnswerCorrect || _answerBlocks.length >= requiredBlockCount) {
      return;
    }
    final block = _findDiscoveredBlock(blockId);
    if (block == null || _answerBlocks.any((item) => item.id == blockId)) {
      return;
    }
    _answerBlocks.add(block);
    _feedbackMessage = '획득한 블록을 문장의 순서에 맞게 놓으세요.';
    _feedbackTone = DiscoveryFeedbackTone.neutral;
    notifyListeners();
  }

  @override
  void removeBlockFromAnswer(String blockId) {
    if (_isAnswerCorrect) {
      return;
    }
    _answerBlocks.removeWhere((block) => block.id == blockId);
    _feedbackMessage = '블록을 획득 보관함으로 돌려보냈어요.';
    _feedbackTone = DiscoveryFeedbackTone.neutral;
    notifyListeners();
  }

  @override
  void revealHint() {
    if (!canRevealHint) {
      return;
    }
    if (_hintLevel < 2) _hintLevel += 1;
    _feedbackMessage = _hintLevel == 1
        ? '힌트: `3개씩 4봉지`는 같은 수를 반복해 더하는 뜻이에요.'
        : '힌트: 먼저 4 × 3을 만들고, 낱개 2를 더해 보세요.';
    _feedbackTone = DiscoveryFeedbackTone.neutral;
    notifyListeners();
  }

  @override
  void resetRound() {
    _resetBoard();
    _selectedCellIndex = null;
    _movesLeft = 18;
    _score = 1240;
    _discoveredBlocks
      ..clear()
      ..addAll(_rewardSequence.take(2));
    _answerBlocks.clear();
    _hintLevel = 0;
    _isAnswerCorrect = false;
    _feedbackMessage = '인접한 보석을 바꿔 수식 블록을 발굴하세요.';
    _feedbackTone = DiscoveryFeedbackTone.neutral;
    notifyListeners();
  }

  @override
  void checkAnswer() {
    final expression = _answerBlocks.map((block) => block.label).join();
    if (_answerBlocks.length < requiredBlockCount) {
      _feedbackMessage = '아직 블록이 부족해요. 보드에서 더 발굴해 보세요.';
      _feedbackTone = DiscoveryFeedbackTone.warning;
    } else if (expression == '4×3+2') {
      _feedbackMessage = '정답이에요! 4봉지의 사탕과 낱개를 올바른 식으로 만들었어요.';
      _feedbackTone = DiscoveryFeedbackTone.success;
      _isAnswerCorrect = true;
    } else {
      _feedbackMessage = '블록은 다 모았어요. `한 봉지의 수 × 봉지 수`를 먼저 생각해 보세요.';
      _feedbackTone = DiscoveryFeedbackTone.warning;
    }
    notifyListeners();
  }

  DiscoveryEquationBlock? _findDiscoveredBlock(String blockId) {
    for (final block in _discoveredBlocks) {
      if (block.id == blockId) {
        return block;
      }
    }
    return null;
  }

  bool _areAdjacent(int first, int second) {
    final firstRow = first ~/ boardColumns;
    final firstColumn = first % boardColumns;
    final secondRow = second ~/ boardColumns;
    final secondColumn = second % boardColumns;
    return (firstRow - secondRow).abs() + (firstColumn - secondColumn).abs() ==
        1;
  }

  void _resetBoard() {
    _boardCells
      ..clear()
      ..addAll(
        List.generate(boardRows * boardColumns, (index) {
          final row = index ~/ boardColumns;
          final column = index % boardColumns;
          final kindIndex =
              (row * 2 + column * 3 + row ~/ 2) %
              DiscoveryGemKind.values.length;
          return DiscoveryGemCell(
            id: 'gem-$index',
            kind: DiscoveryGemKind.values[kindIndex],
          );
        }),
      );
  }
}
