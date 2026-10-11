import 'package:flutter/foundation.dart';

import '../domain/equation_engine.dart';
import '../domain/equation_token.dart';
import '../domain/puzzle.dart';

enum FeedbackTone { neutral, error, success }

class PuzzleController extends ChangeNotifier {
  PuzzleController({
    required List<Puzzle> puzzles,
    this.validator = const PuzzleValidator(),
  }) : puzzles = List.unmodifiable(puzzles) {
    if (puzzles.isEmpty) {
      throw ArgumentError.value(puzzles, 'puzzles', 'Must not be empty.');
    }
  }

  final List<Puzzle> puzzles;
  final PuzzleValidator validator;

  int _puzzleIndex = 0;
  int _wrongAnswerCount = 0;
  int _usedHintCount = 0;
  int _hintLevel = 0;
  bool _isStageComplete = false;
  List<EquationToken> _expression = [];
  final List<List<EquationToken>> _history = [];
  PuzzleValidationResult? _lastResult;
  String? _selectedTokenId;

  Puzzle get puzzle => puzzles[_puzzleIndex];
  int get puzzleIndex => _puzzleIndex;
  int get totalPuzzleCount => puzzles.length;
  int get wrongAnswerCount => _wrongAnswerCount;
  int get usedHintCount => _usedHintCount;
  int get hintLevel => _hintLevel;
  bool get isStageComplete => _isStageComplete;
  bool get isCorrect => _lastResult?.isCorrect ?? false;
  bool get canUndo => _history.isNotEmpty && !isCorrect;
  bool get canReset => _expression.isNotEmpty && !isCorrect;
  bool get canRevealHint =>
      _hintLevel < puzzle.effectiveHints.length && !isCorrect;
  List<EquationToken> get expression => List.unmodifiable(_expression);

  int? get selectedTokenIndex {
    final selectedTokenId = _selectedTokenId;
    if (selectedTokenId == null) {
      return null;
    }
    final index = _expression.indexWhere(
      (token) => token.id == selectedTokenId,
    );
    return index < 0 ? null : index;
  }

  EquationToken? get selectedToken {
    final index = selectedTokenIndex;
    return index == null ? null : _expression[index];
  }

  bool get canMoveSelectedTokenLeft {
    final index = selectedTokenIndex;
    return !isCorrect && index != null && index > 0;
  }

  bool get canMoveSelectedTokenRight {
    final index = selectedTokenIndex;
    return !isCorrect && index != null && index < _expression.length - 1;
  }

  bool get canRemoveSelectedToken => !isCorrect && selectedTokenIndex != null;

  List<EquationToken> get availableTokens {
    final usedIds = _expression.map((token) => token.id).toSet();
    return puzzle.tokens
        .where((token) => !usedIds.contains(token.id))
        .toList(growable: false);
  }

  String? get currentHint =>
      _hintLevel == 0 ? null : puzzle.effectiveHints[_hintLevel - 1];

  int get projectedStars {
    if (_wrongAnswerCount == 0 && _usedHintCount <= 1) {
      return 3;
    }
    if (_wrongAnswerCount <= 2 && _usedHintCount <= 3) {
      return 2;
    }
    return 1;
  }

  FeedbackTone get feedbackTone {
    if (_lastResult == null) {
      return FeedbackTone.neutral;
    }
    return isCorrect ? FeedbackTone.success : FeedbackTone.error;
  }

  String? get feedbackMessage {
    final result = _lastResult;
    if (result == null) {
      return null;
    }
    return switch (result.reason) {
      PuzzleValidationReason.empty => '아직 식이 비어 있어요. 블록을 눌러 식을 만들어 보세요.',
      PuzzleValidationReason.missingRequiredToken =>
        '문장에 나온 핵심 수와 연산 블록을 모두 사용해 보세요.',
      PuzzleValidationReason.duplicatedToken => '같은 블록을 두 번 사용할 수 없어요.',
      PuzzleValidationReason.unknownToken => '이 문제에서 사용할 수 없는 블록이 포함되어 있어요.',
      PuzzleValidationReason.distractorUsed => '문장에 필요하지 않은 블록이 하나 섞여 있어요.',
      PuzzleValidationReason.invalidSyntax => _syntaxMessage(
        result.evaluation?.error,
      ),
      PuzzleValidationReason.wrongValue =>
        result.isStructureMismatch
            ? '계산값은 맞지만 문장의 관계를 나타내는 식이 아니에요. 수와 연산의 순서를 다시 확인해 보세요.'
            : '식의 값이 ${result.evaluation?.value ?? '?'}예요. 문장을 다시 확인해 보세요.',
      PuzzleValidationReason.correct => '정답이에요! ${puzzle.explanation}',
    };
  }

  void addToken(EquationToken token) {
    if (isCorrect || _expression.any((item) => item.id == token.id)) {
      return;
    }
    _rememberExpression();
    _expression = [..._expression, token];
    _selectedTokenId = token.id;
    _clearFeedback();
    notifyListeners();
  }

  void selectTokenAt(int index) {
    if (isCorrect || index < 0 || index >= _expression.length) {
      return;
    }
    final tokenId = _expression[index].id;
    if (_selectedTokenId == tokenId) {
      return;
    }
    _selectedTokenId = tokenId;
    notifyListeners();
  }

  void removeTokenAt(int index) {
    if (isCorrect || index < 0 || index >= _expression.length) {
      return;
    }
    _rememberExpression();
    final removedTokenId = _expression[index].id;
    _expression = [..._expression]..removeAt(index);
    if (_selectedTokenId == removedTokenId) {
      _selectedTokenId = null;
    }
    _clearFeedback();
    notifyListeners();
  }

  void removeSelectedToken() {
    final index = selectedTokenIndex;
    if (index != null) {
      removeTokenAt(index);
    }
  }

  void reorderToken(int oldIndex, int newIndex) {
    if (isCorrect || oldIndex < 0 || oldIndex >= _expression.length) {
      return;
    }
    _rememberExpression();
    final reordered = [..._expression];
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final token = reordered.removeAt(oldIndex);
    final targetIndex = newIndex.clamp(0, reordered.length);
    reordered.insert(targetIndex, token);
    _expression = reordered;
    _selectedTokenId = token.id;
    _clearFeedback();
    notifyListeners();
  }

  void moveSelectedTokenLeft() => _moveSelectedTokenBy(-1);

  void moveSelectedTokenRight() => _moveSelectedTokenBy(1);

  void undo() {
    if (!canUndo) {
      return;
    }
    _expression = _history.removeLast();
    _selectedTokenId = null;
    _clearFeedback();
    notifyListeners();
  }

  void resetExpression() {
    if (!canReset) {
      return;
    }
    _rememberExpression();
    _expression = [];
    _selectedTokenId = null;
    _clearFeedback();
    notifyListeners();
  }

  void revealHint() {
    if (!canRevealHint) {
      return;
    }
    _hintLevel += 1;
    _usedHintCount += 1;
    notifyListeners();
  }

  void submit() {
    if (isCorrect || _isStageComplete) {
      return;
    }
    final result = validator.validate(puzzle, _expression);
    _lastResult = result;
    if (!result.isCorrect) {
      _wrongAnswerCount += 1;
    }
    notifyListeners();
  }

  void goToNextPuzzle() {
    if (!isCorrect) {
      return;
    }
    if (_puzzleIndex == puzzles.length - 1) {
      _isStageComplete = true;
      notifyListeners();
      return;
    }
    _puzzleIndex += 1;
    _resetPuzzleState();
    notifyListeners();
  }

  void restartStage() {
    _puzzleIndex = 0;
    _wrongAnswerCount = 0;
    _usedHintCount = 0;
    _isStageComplete = false;
    _resetPuzzleState();
    notifyListeners();
  }

  void _rememberExpression() {
    _history.add(List.of(_expression));
    if (_history.length > 30) {
      _history.removeAt(0);
    }
  }

  void _moveSelectedTokenBy(int offset) {
    if (isCorrect) {
      return;
    }
    final oldIndex = selectedTokenIndex;
    if (oldIndex == null) {
      return;
    }
    final newIndex = oldIndex + offset;
    if (newIndex < 0 || newIndex >= _expression.length) {
      return;
    }
    _rememberExpression();
    final reordered = [..._expression];
    final token = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, token);
    _expression = reordered;
    _clearFeedback();
    notifyListeners();
  }

  void _clearFeedback() {
    _lastResult = null;
  }

  void _resetPuzzleState() {
    _expression = [];
    _history.clear();
    _hintLevel = 0;
    _lastResult = null;
    _selectedTokenId = null;
  }

  String _syntaxMessage(EquationErrorCode? error) {
    return switch (error) {
      EquationErrorCode.emptyExpression => '아직 식이 비어 있어요.',
      EquationErrorCode.expectedOperand => '연산자 옆에는 수나 여는 괄호가 필요해요.',
      EquationErrorCode.expectedOperator => '두 수 사이에는 연산자가 필요해요.',
      EquationErrorCode.unbalancedParentheses => '여는 괄호와 닫는 괄호의 짝을 확인해 보세요.',
      EquationErrorCode.unsupportedOperator => '지원하지 않는 연산자가 포함되어 있어요.',
      EquationErrorCode.invalidNumber => '읽을 수 없는 수 블록이 있어요.',
      EquationErrorCode.divisionByZero => '0으로 나눌 수 없어요.',
      EquationErrorCode.malformedExpression || null => '식의 순서를 다시 확인해 보세요.',
    };
  }
}
