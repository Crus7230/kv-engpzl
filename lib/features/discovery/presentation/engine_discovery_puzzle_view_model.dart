import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../campaign/data/initial_campaign.dart';
import '../../campaign/domain/campaign_models.dart';
import '../../campaign/domain/board_mechanic_models.dart';
import '../../campaign/domain/learning_models.dart';
import '../../puzzle/domain/authored_expression_checker.dart';
import '../../puzzle/domain/equation_token.dart';
import '../../puzzle/domain/puzzle.dart';
import '../../puzzle/domain/puzzle_learning_support.dart';
import '../data/discovery_runtime_catalog.dart';
import '../domain/discovery_engine.dart';
import '../domain/discovery_models.dart';
import '../domain/discovery_piece_source.dart';
import 'discovery_board_motion.dart';
import 'discovery_puzzle_view_model.dart';

StageDefinition _prototypePlayableStage() {
  final playableStages = prototypeCampaign.stages
      .where((stage) => stage.isPlayable)
      .toList(growable: false);
  if (playableStages.length != 1) {
    throw StateError(
      'The prototype campaign must expose exactly one playable stage.',
    );
  }
  return playableStages.single;
}

class EngineDiscoveryPuzzleViewModel extends ChangeNotifier
    implements DiscoveryPuzzleViewModel, DiscoveryBoardMotionSource {
  EngineDiscoveryPuzzleViewModel({
    required DiscoveryBoardConfig boardConfig,
    StageDefinition? stage,
    DiscoveryRuntimeCatalog? runtimeCatalog,
  }) : _boardConfig = boardConfig,
       _stage = stage ?? _prototypePlayableStage() {
    _runtime = (runtimeCatalog ?? discoveryRuntimeCatalog).resolve(_stage);
    _validateSupportedStage();
    _boardVariant = _resolveBoardVariant();
    _puzzle = _runtime.puzzle;
    _validatePuzzleLearningSupport();
    _tutorialTargetIds = _resolveTutorialTargetIds();
    _boardCellsView = UnmodifiableListView(_boardCells);
    _discoveredBlocksView = UnmodifiableListView(_discoveredBlocks);
    _answerBlocksView = UnmodifiableListView(_answerBlocks);
    _resetSession();
  }

  final DiscoveryBoardConfig _boardConfig;
  final StageDefinition _stage;
  late final DiscoveryStageRuntime _runtime;
  late final BoardLayoutVariant _boardVariant;
  late final Puzzle _puzzle;
  late final List<String> _tutorialTargetIds;
  final PuzzleValidator _validator = const PuzzleValidator();
  final List<DiscoveryGemCell> _boardCells = [];
  final List<DiscoveryEquationBlock> _discoveredBlocks = [];
  final List<DiscoveryEquationBlock> _answerBlocks = [];
  late final List<DiscoveryGemCell> _boardCellsView;
  late final List<DiscoveryEquationBlock> _discoveredBlocksView;
  late final List<DiscoveryEquationBlock> _answerBlocksView;
  late DiscoveryEngine _engine;

  int? _selectedCellIndex;
  int _score = 0;
  int _hintLevel = 0;
  String _feedbackMessage = '튜토리얼: 첫째 줄 두 번째 보석을 바로 아래 보석과 바꿔 보세요.';
  DiscoveryFeedbackTone _feedbackTone = DiscoveryFeedbackTone.neutral;
  bool _isAnswerCorrect = false;
  final List<List<int>> _acceptedSwaps = [];
  final Set<String> _misconceptionIds = {};
  int _submissionCount = 0;
  bool _firstSubmissionCorrect = false;
  bool _usedDirectPathHint = false;
  int _boardMotionRevision = 0;
  DiscoveryBoardTurnMotion? _boardTurnMotion;

  @override
  int get boardMotionRevision => _boardMotionRevision;

  @override
  DiscoveryBoardTurnMotion? get boardTurnMotion => _boardTurnMotion;

  StageDefinition get stage => _stage;
  Set<String> get misconceptionIds => Set.unmodifiable(_misconceptionIds);
  StageAttemptMetrics get attemptMetrics => StageAttemptMetrics(
    completed: _isAnswerCorrect,
    movesUsed: _acceptedSwaps.length,
    meaningfulSubmissionCount: _submissionCount,
    firstMeaningfulSubmissionCorrect: _firstSubmissionCorrect,
    highestMathHintTierUsed: _hintLevel,
    usedDirectPathHint: _usedDirectPathHint,
    usedGuidedCompletion:
        _stage.assistRules.tutorialMode == StageTutorialMode.forced,
  );

  /// Replaying accepted swaps restores the refill RNG and board exactly.
  /// The materialized board is retained as a verification snapshot as well.
  Map<String, dynamic> exportSession() => {
    'sessionVersion': 1,
    'stageId': _stage.id,
    'puzzleId': _puzzle.id,
    'fixtureId': _boardVariant.fixtureId,
    'problemSeed': _stage.seed,
    'boardSeed': _boardVariant.seed,
    'rows': boardRows,
    'columns': boardColumns,
    'acceptedSwaps': [
      for (final swap in _acceptedSwaps) [...swap],
    ],
    'boardState': _boardSnapshot(),
    'discoveredTokenIds': _discoveredBlocks.map((b) => b.id).toList(),
    'answerTokenIds': _answerBlocks.map((b) => b.id).toList(),
    'hintLevel': _hintLevel,
    'submissionCount': _submissionCount,
    'firstSubmissionCorrect': _firstSubmissionCorrect,
    'usedDirectPathHint': _usedDirectPathHint,
    'misconceptionIds': _misconceptionIds.toList(),
    'isAnswerCorrect': _isAnswerCorrect,
    'selectedCellIndex': _selectedCellIndex,
    'feedbackMessage': _feedbackMessage,
    'feedbackTone': _feedbackTone.name,
  };

  Map<String, dynamic> _boardSnapshot() => {
    'movesRemaining': movesLeft,
    if (_engine.state.linePowerActivations > 0)
      'linePowerActivations': _engine.state.linePowerActivations,
    'cells': [
      for (final row in _engine.state.board.cells)
        [
          for (final cell in row)
            {
              'id': cell.piece!.id,
              'matchKey': cell.piece!.matchKey,
              'targetId': cell.buriedTarget?.id,
              if (cell.sealLayers > 1) 'sealLayers': cell.sealLayers,
              if (cell.piece!.linePower != null)
                'linePower': cell.piece!.linePower!.name,
            },
        ],
    ],
  };

  void restoreSession(Map<String, dynamic> saved) {
    try {
      _restoreSession(saved);
    } catch (error) {
      _resetSession();
      notifyListeners();
      if (error is FormatException) rethrow;
      throw const FormatException('Invalid saved session data.');
    }
  }

  void _restoreSession(Map<String, dynamic> saved) {
    if (saved['sessionVersion'] != 1 ||
        saved['stageId'] != _stage.id ||
        saved['puzzleId'] != _puzzle.id ||
        saved['fixtureId'] != _boardVariant.fixtureId ||
        saved['problemSeed'] != _stage.seed ||
        saved['boardSeed'] != _boardVariant.seed ||
        saved['rows'] != _boardConfig.rows ||
        saved['columns'] != _boardConfig.columns) {
      throw const FormatException(
        'Session content or fixture version mismatch.',
      );
    }
    final swaps = saved['acceptedSwaps'];
    if (swaps is! List || swaps.length > _stage.moveLimit) {
      throw const FormatException('Invalid replay length.');
    }
    _resetSession();
    for (final item in swaps) {
      if (item is! List ||
          item.length != 2 ||
          item.any(
            (index) =>
                index is! int || index < 0 || index >= boardRows * boardColumns,
          )) {
        throw const FormatException('Invalid replay swap.');
      }
      selectGem(item[0] as int);
      final count = _acceptedSwaps.length;
      selectGem(item[1] as int);
      if (_acceptedSwaps.length != count + 1) {
        throw const FormatException(
          'Saved swap no longer matches the fixture.',
        );
      }
    }
    if (jsonEncode(_boardSnapshot()) != jsonEncode(saved['boardState']) ||
        jsonEncode(_discoveredBlocks.map((b) => b.id).toList()) !=
            jsonEncode(saved['discoveredTokenIds'])) {
      throw const FormatException(
        'Saved board differs from deterministic replay.',
      );
    }
    final answers = saved['answerTokenIds'];
    if (answers is! List ||
        answers.length > requiredBlockCount ||
        answers.toSet().length != answers.length ||
        answers.any(
          (id) => id is! String || _findBlock(_discoveredBlocks, id) == null,
        )) {
      throw const FormatException('Invalid saved expression.');
    }
    _answerBlocks
      ..clear()
      ..addAll(answers.map((id) => _blockForTokenId(id as String)));
    final hintLevel = saved['hintLevel'];
    final submissions = saved['submissionCount'];
    if (hintLevel is! int ||
        hintLevel < 0 ||
        hintLevel > _learningSupport.hintSteps.length ||
        submissions is! int ||
        submissions < 0 ||
        submissions > 10000 ||
        saved['firstSubmissionCorrect'] is! bool ||
        saved['usedDirectPathHint'] is! bool ||
        saved['isAnswerCorrect'] is! bool ||
        saved['misconceptionIds'] is! List ||
        (saved['misconceptionIds'] as List).any((id) => id is! String) ||
        saved['feedbackMessage'] is! String ||
        !DiscoveryFeedbackTone.values.any(
          (tone) => tone.name == saved['feedbackTone'],
        )) {
      throw const FormatException('Invalid saved learning evidence.');
    }
    _hintLevel = hintLevel;
    _submissionCount = submissions;
    _firstSubmissionCorrect = saved['firstSubmissionCorrect'] as bool;
    _usedDirectPathHint = saved['usedDirectPathHint'] as bool;
    _misconceptionIds
      ..clear()
      ..addAll((saved['misconceptionIds'] as List).cast<String>());
    _isAnswerCorrect = saved['isAnswerCorrect'] as bool;
    if (_isAnswerCorrect &&
        (!_engine.state.isCompleted ||
            _submissionCount == 0 ||
            !_validator
                .validate(
                  _puzzle,
                  _answerBlocks.map((b) => _tokenForId(b.id)).toList(),
                )
                .isCorrect)) {
      throw const FormatException(
        'Saved completion has no correct expression.',
      );
    }
    final selected = saved['selectedCellIndex'];
    if (selected != null &&
        (selected is! int ||
            selected < 0 ||
            selected >= boardRows * boardColumns)) {
      throw const FormatException('Invalid selected cell.');
    }
    _selectedCellIndex = selected as int?;
    _feedbackMessage = saved['feedbackMessage'] as String;
    _feedbackTone = DiscoveryFeedbackTone.values.byName(
      saved['feedbackTone'] as String,
    );
    // Replaying a checkpoint restores state, not a pending visual turn.
    _clearBoardMotion();
    notifyListeners();
  }

  @override
  String get stageLabel => _stage.title;

  @override
  String get difficultyLabel =>
      '수학 ${_stage.mathDifficulty.tier.index} · '
      '퍼즐 ${_stage.matchDifficulty.tier.index}';

  @override
  String get concept => _stage.conceptLabel;

  @override
  String get question => _puzzle.question;

  @override
  String get visualDescription => _puzzle.visualDescription.isEmpty
      ? _puzzle.question
      : _puzzle.visualDescription;

  @override
  String get learningObjective => _learningSupport.learningObjective;

  @override
  List<PuzzleWorkedSolutionStep> get workedSolutionSteps =>
      _learningSupport.workedSolutionSteps;

  @override
  PuzzleTransferPrompt get transferPrompt => _learningSupport.transferPrompt;

  @override
  int get movesLeft => _engine.state.movesRemaining;

  @override
  int get score => _score;

  @override
  int get boardRows => _engine.state.board.rowCount;

  @override
  int get boardColumns => _engine.state.board.columnCount;

  @override
  List<DiscoveryGemCell> get boardCells => _boardCellsView;

  @override
  int? get selectedCellIndex => _selectedCellIndex;

  @override
  int get requiredBlockCount => _puzzle.requiredTokenIds.length;

  @override
  List<DiscoveryEquationBlock> get discoveredBlocks => _discoveredBlocksView;

  @override
  List<DiscoveryEquationBlock> get answerBlocks => _answerBlocksView;

  @override
  String get feedbackMessage => _feedbackMessage;

  @override
  DiscoveryFeedbackTone get feedbackTone => _feedbackTone;

  @override
  bool get canCheckAnswer =>
      _answerBlocks.length == requiredBlockCount &&
      !_isAnswerCorrect &&
      _engine.state.isCompleted;

  @override
  bool get canRevealHint =>
      !_isAnswerCorrect &&
      (!_engine.state.isCompleted ||
          _hintLevel < _learningSupport.hintSteps.length);

  @override
  bool get isAnswerCorrect => _isAnswerCorrect;

  @override
  void selectGem(int index) {
    if (_isAnswerCorrect ||
        movesLeft <= 0 ||
        index < 0 ||
        index >= _boardCells.length) {
      return;
    }

    final selected = _selectedCellIndex;
    if (selected == null) {
      _selectedCellIndex = index;
      _setFeedback('바꿀 인접 보석을 하나 더 선택하세요.', DiscoveryFeedbackTone.neutral);
      notifyListeners();
      return;
    }
    if (selected == index) {
      _selectedCellIndex = null;
      _setFeedback('선택을 취소했어요.', DiscoveryFeedbackTone.neutral);
      notifyListeners();
      return;
    }

    final from = _positionForIndex(selected);
    final to = _positionForIndex(index);
    if (!from.isAdjacentTo(to)) {
      _selectedCellIndex = index;
      _setFeedback('가로나 세로로 맞닿은 보석만 바꿀 수 있어요.', DiscoveryFeedbackTone.warning);
      notifyListeners();
      return;
    }
    final collectedTargetIds = _engine.state.collectedTargetIds;
    if (!_isExpectedTutorialSwap(from, to, collectedTargetIds)) {
      _selectedCellIndex = null;
      _setFeedback(
        '첫 튜토리얼에서는 안내된 두 보석을 바꿔 봉인을 하나씩 열어 보세요.',
        DiscoveryFeedbackTone.warning,
      );
      notifyListeners();
      return;
    }

    final boardBeforeSwap = _engine.state.board;
    final result = _engine.swap(from, to);
    if (result.isAccepted || result.status == DiscoverySwapStatus.noMatch) {
      _boardTurnMotion = _turnMotion(boardBeforeSwap, result);
      _boardMotionRevision += 1;
    }
    _selectedCellIndex = null;
    switch (result.status) {
      case DiscoverySwapStatus.accepted:
        _acceptedSwaps.add([selected, index]);
        _refreshBoardCells();
        final clearedCount = result.cascades.fold<int>(
          0,
          (total, step) => total + step.clearedPieces.length,
        );
        _score +=
            clearedCount * 30 + result.newlyDiscoveredTargets.length * 200;
        for (final target in result.newlyDiscoveredTargets) {
          _addDiscoveredToken(target.id);
        }
        if (result.newlyDiscoveredTargets.isNotEmpty) {
          final labels = result.newlyDiscoveredTargets
              .map((piece) => piece.label)
              .join(', ');
          _setFeedback(
            '$labels 발굴! ${_nextDiscoveryInstruction(result.state.collectedTargetIds)}',
            DiscoveryFeedbackTone.reward,
          );
        } else if (result.cascades.any((c) => c.activatedPowers.isNotEmpty)) {
          _setFeedback(
            '직선 파워가 한 줄을 타격했어요. 남은 봉인을 확인하세요.',
            DiscoveryFeedbackTone.reward,
          );
        } else if (result.cascades.any((c) => c.createdPowers.isNotEmpty)) {
          _setFeedback(
            '4개 매치로 직선 파워 생성! 인접 보석과 바꾸면 한 줄을 타격해요.',
            DiscoveryFeedbackTone.reward,
          );
        } else if (result.cascades.any((c) => c.sealHits.isNotEmpty)) {
          _setFeedback(
            '봉인이 한 층 벗겨졌어요. 같은 칸을 다시 타격하세요.',
            DiscoveryFeedbackTone.reward,
          );
        } else {
          _setFeedback(
            '매치 성공! 봉인이 있는 칸을 노려 보세요.',
            DiscoveryFeedbackTone.reward,
          );
        }
        if (result.state.isDeadBoard) {
          _setFeedback(
            '더 만들 수 있는 매치가 없어요. 무료 초기화로 다시 배치할 수 있어요.',
            DiscoveryFeedbackTone.warning,
          );
        } else if (result.state.isOutOfMoves) {
          _setFeedback(
            '이동을 모두 사용했어요. 무료로 다시 도전할 수 있어요.',
            DiscoveryFeedbackTone.warning,
          );
        }
      case DiscoverySwapStatus.noMatch:
        _setFeedback(
          '3개가 이어지지 않아 원래 자리로 돌아왔어요. 이동 수는 줄지 않아요.',
          DiscoveryFeedbackTone.warning,
        );
      case DiscoverySwapStatus.notAdjacent:
        _setFeedback(
          '가로나 세로로 맞닿은 보석만 바꿀 수 있어요.',
          DiscoveryFeedbackTone.warning,
        );
      case DiscoverySwapStatus.invalidPosition:
        _setFeedback('선택한 칸을 확인해 주세요.', DiscoveryFeedbackTone.warning);
      case DiscoverySwapStatus.noMovesRemaining:
        _setFeedback(
          '이동을 모두 사용했어요. 무료로 다시 도전할 수 있어요.',
          DiscoveryFeedbackTone.warning,
        );
      case DiscoverySwapStatus.alreadyCompleted:
        _setFeedback(
          '필요한 블록을 모두 찾았어요. 오른쪽에서 식을 완성하세요.',
          DiscoveryFeedbackTone.reward,
        );
    }
    notifyListeners();
  }

  @override
  void addBlockToAnswer(String blockId) {
    if (_isAnswerCorrect || _answerBlocks.length >= requiredBlockCount) {
      return;
    }
    final block = _findBlock(_discoveredBlocks, blockId);
    if (block == null || _answerBlocks.any((item) => item.id == blockId)) {
      return;
    }
    _answerBlocks.add(block);
    _setFeedback('발굴한 블록을 문장의 관계에 맞게 놓으세요.', DiscoveryFeedbackTone.neutral);
    notifyListeners();
  }

  @override
  void removeBlockFromAnswer(String blockId) {
    if (_isAnswerCorrect) {
      return;
    }
    _answerBlocks.removeWhere((block) => block.id == blockId);
    _setFeedback('블록을 발굴 보관함으로 돌려보냈어요.', DiscoveryFeedbackTone.neutral);
    notifyListeners();
  }

  @override
  void revealHint() {
    if (!canRevealHint) {
      return;
    }
    final state = _engine.state;
    if (!state.isCompleted) {
      if (state.isOutOfMoves || state.isDeadBoard) {
        _setFeedback(
          state.isOutOfMoves
              ? '이동을 모두 사용했어요. 무료 초기화로 다시 도전하세요.'
              : '현재 보드에 가능한 매치가 없어요. 무료 초기화로 다시 도전하세요.',
          DiscoveryFeedbackTone.warning,
        );
        notifyListeners();
        return;
      }
      _usedDirectPathHint = true;
      _selectedCellIndex = null;
      final suggestion = _runtime.suggestSwapFor?.call(
        _boardVariant,
        _acceptedSwaps,
      );
      final instruction = suggestion == null
          ? _nextDiscoveryInstruction(state.collectedTargetIds)
          : '${suggestion.from.row + 1}행 ${suggestion.from.column + 1}열과 '
                '${suggestion.to.row + 1}행 ${suggestion.to.column + 1}열을 바꾸세요. '
                '${suggestion.targetId == null
                    ? suggestion.activatesLinePower
                          ? '직선 파워를 활성하는 경로예요. 한 줄의 봉인을 함께 타격해요.'
                          : suggestion.createsLinePower
                          ? '직선 파워를 생성하는 경로예요. 생성 뒤 인접 교환으로 활성하세요.'
                          : '가능한 교환이에요. 봉인까지의 경로는 아직 확인하지 못했어요.'
                    : suggestion.movesToTarget == 1
                    ? '${_tokenForId(suggestion.targetId!).label} 조각을 발굴할 수 있어요.'
                    : '봉인까지 ${suggestion.movesToTarget}회 경로의 첫 교환이에요. 이동 뒤 힌트를 다시 확인하세요.'}';
      _setFeedback('발굴 힌트: $instruction', DiscoveryFeedbackTone.neutral);
      notifyListeners();
      return;
    }
    final support = _learningSupport;
    if (_hintLevel < support.hintSteps.length) {
      _hintLevel += 1;
    }
    final hint = support.hintSteps[_hintLevel - 1];
    _setFeedback(
      '힌트 $_hintLevel/${support.hintSteps.length} · '
      '${_hintKindLabel(hint.kind)}: ${hint.message}',
      DiscoveryFeedbackTone.neutral,
    );
    notifyListeners();
  }

  @override
  void resetRound() {
    _resetSession();
    notifyListeners();
  }

  @override
  void checkAnswer() {
    if (!canCheckAnswer) return;
    final tokensById = {for (final token in _puzzle.tokens) token.id: token};
    final expression = <EquationToken>[
      for (final block in _answerBlocks) tokensById[block.id]!,
    ];
    final result = _validator.validate(_puzzle, expression);
    if (result.reason != PuzzleValidationReason.invalidSyntax &&
        result.reason != PuzzleValidationReason.empty &&
        result.reason != PuzzleValidationReason.missingRequiredToken) {
      _submissionCount += 1;
      if (_submissionCount == 1) _firstSubmissionCorrect = result.isCorrect;
      if (!result.isCorrect)
        _misconceptionIds.add(_misconceptionCategoryFor(result).name);
    }
    if (result.isCorrect) {
      _isAnswerCorrect = true;
      _setFeedback(
        '정답이에요! ${_puzzle.explanation}',
        DiscoveryFeedbackTone.success,
      );
    } else {
      final category = _misconceptionCategoryFor(result);
      final message = _learningSupport.feedbackFor(category);
      if (message == null) {
        throw StateError(
          'Puzzle ${_puzzle.id} has no feedback for ${category.name}.',
        );
      }
      _setFeedback(message, DiscoveryFeedbackTone.warning);
    }
    notifyListeners();
  }

  void _validateSupportedStage() {
    if (!_stage.isPlayable ||
        _stage.learningPlan.status != LearningPlanStatus.authored) {
      throw ArgumentError.value(
        _stage.id,
        'stage',
        'Only authored playable stages can start a session.',
      );
    }
    if (_stage.assistRules.tutorialMode == StageTutorialMode.forced &&
        _runtime.tutorialSteps.isEmpty) {
      throw ArgumentError.value(
        _stage.id,
        'stage',
        'A forced tutorial requires authored swap instructions.',
      );
    }
    if (_stage.decoyTokenIds.isNotEmpty ||
        _stage.matchDifficulty.decoySealCount != 0 ||
        _stage.matchDifficulty.maxSealLayers > 2 ||
        _stage.matchDifficulty.obstacleCount != 0 ||
        !currentDiscoveryBoardMechanics.supportsForPlay(
          _stage.boardMechanicPlan,
        ) ||
        (_stage.matchDifficulty.specialRule ==
                MatchSpecialRule.fourMatchPower) !=
            _runtime.enableLinePowers) {
      throw ArgumentError.value(
        _stage.id,
        'stage',
        'The fixture supports seals up to two layers and optional line powers.',
      );
    }
    if (_stage.matchDifficulty.gemKindCount != _runtime.gemKeys.length) {
      throw ArgumentError.value(
        _stage.matchDifficulty.gemKindCount,
        'stage.matchDifficulty.gemKindCount',
        'Gem kinds must match the runtime fixture.',
      );
    }
  }

  BoardLayoutVariant _resolveBoardVariant() {
    if (!_stage.boardVariants.supports(_boardConfig)) {
      throw ArgumentError.value(
        '${_boardConfig.rows}x${_boardConfig.columns}',
        'boardConfig',
        'The stage has no fixture for this board layout.',
      );
    }
    final variant = _stage.boardVariants.variantFor(_boardConfig);
    if (!variant.isVerified) {
      throw ArgumentError.value(
        variant.fixtureId,
        'boardConfig',
        'The selected board fixture has not been verified for play.',
      );
    }
    return variant;
  }

  void _validatePuzzleLearningSupport() {
    if (_puzzle.id != _stage.puzzleId)
      throw StateError('Runtime puzzle ID mismatch.');
    if (!_stage.isPlayable) {
      return;
    }
    final support = _puzzle.learningSupport;
    if (support == null || !support.hasCompletePlayableSupport) {
      throw ArgumentError.value(
        _puzzle.id,
        'stage.puzzleId',
        'A playable stage requires typed hints, misconception feedback, '
            'worked solution steps, and a transfer prompt.',
      );
    }
    const expressionChecker = AuthoredExpressionChecker();
    final workedChecks = [
      for (final step in support.workedSolutionSteps)
        expressionChecker.evaluateEquation(step.expression),
    ];
    if (workedChecks.any((check) => !check.isValid) ||
        workedChecks.last.value != _puzzle.target ||
        !expressionChecker
            .evaluate(support.transferPrompt.expectedExpression)
            .isValid) {
      throw ArgumentError.value(
        _puzzle.id,
        'stage.puzzleId',
        'Playable learning explanations must contain valid arithmetic.',
      );
    }
  }

  PuzzleLearningSupport get _learningSupport {
    final support = _puzzle.learningSupport;
    if (support == null) {
      throw StateError(
        'Playable puzzle ${_puzzle.id} has no learning support.',
      );
    }
    return support;
  }

  List<String> _resolveTutorialTargetIds() {
    final configuredRequiredIds = {
      ..._stage.startingTokenIds,
      ..._stage.buriedTokenIds,
    };
    if (configuredRequiredIds.length != _puzzle.requiredTokenIds.length ||
        !configuredRequiredIds.containsAll(_puzzle.requiredTokenIds)) {
      throw ArgumentError.value(
        configuredRequiredIds,
        'stage',
        'Starting and buried tokens must exactly cover required puzzle tokens.',
      );
    }
    if (_stage.buriedTokenIds.length !=
        _stage.matchDifficulty.requiredSealCount) {
      throw ArgumentError.value(
        _stage.buriedTokenIds,
        'stage.buriedTokenIds',
        'Buried token count must match the required seal count.',
      );
    }

    final ids = _runtime.tutorialSteps.map((step) => step.targetId).toList();
    if (ids.any((id) => !_stage.buriedTokenIds.contains(id))) {
      throw StateError('Tutorial targets must belong to the stage token plan.');
    }
    return ids;
  }

  void _resetSession() {
    _clearBoardMotion();
    _engine = DiscoveryEngine(
      initialBoard: _buildInitialBoard(),
      requiredTargetIds: _stage.buriedTokenIds,
      moves: _stage.moveLimit,
      enableLinePowers: _runtime.enableLinePowers,
      requiredLinePowerActivations: _runtime.requiredLinePowerActivations,
      refillSource: QueuedPieceSource(
        pieces: _runtime.refillPieces(_boardVariant),
        fallback: SeededGemPieceSource(
          seed: _boardVariant.seed,
          idPrefix: '${_stage.id}-${_boardVariant.fixtureId}-refill',
          gemKeys: _runtime.gemKeys,
        ),
      ),
    );
    _selectedCellIndex = null;
    _score = 0;
    _hintLevel = 0;
    _isAnswerCorrect = false;
    _acceptedSwaps.clear();
    _misconceptionIds.clear();
    _submissionCount = 0;
    _firstSubmissionCorrect = false;
    _usedDirectPathHint = false;
    _answerBlocks.clear();
    _discoveredBlocks
      ..clear()
      ..addAll([
        for (final id in _stage.startingTokenIds) _blockForTokenId(id),
      ]);
    _setFeedback(
      _nextDiscoveryInstruction(const {}),
      DiscoveryFeedbackTone.neutral,
    );
    _refreshBoardCells();
  }

  DiscoveryBoard _buildInitialBoard() {
    return _runtime.buildBoard(_boardVariant);
  }

  void _clearBoardMotion() {
    _boardTurnMotion = null;
    _boardMotionRevision += 1;
  }

  DiscoveryBoardTurnMotion _turnMotion(
    DiscoveryBoard before,
    DiscoveryTurnResult result,
  ) {
    final beforeCells = _motionCells(before);
    final fromIndex = result.from.row * boardColumns + result.from.column;
    final toIndex = result.to.row * boardColumns + result.to.column;
    final swappedCells = List<DiscoveryMotionCell>.of(beforeCells);
    // Seals belong to board coordinates; only the visible gems exchange places.
    swappedCells[fromIndex] = DiscoveryMotionCell(
      gem: beforeCells[toIndex].gem,
      sealKind: beforeCells[fromIndex].sealKind,
      sealLayers: beforeCells[fromIndex].sealLayers,
    );
    swappedCells[toIndex] = DiscoveryMotionCell(
      gem: beforeCells[fromIndex].gem,
      sealKind: beforeCells[toIndex].sealKind,
      sealLayers: beforeCells[toIndex].sealLayers,
    );
    int indexFor(DiscoveryPosition position) =>
        position.row * boardColumns + position.column;
    DiscoveryMotionPower powerFor(DiscoveryPowerEvent event) =>
        DiscoveryMotionPower(
          index: indexFor(event.position),
          direction: event.direction == DiscoveryLinePower.row
              ? DiscoveryLinePowerKind.row
              : DiscoveryLinePowerKind.column,
        );
    return DiscoveryBoardTurnMotion(
      fromIndex: fromIndex,
      toIndex: toIndex,
      accepted: result.isAccepted,
      beforeSwap: beforeCells,
      afterSwap: swappedCells,
      cascades: [
        for (final step in result.cascades)
          DiscoveryCascadeMotion(
            index: step.index,
            clearedIndices: step.clearedPieces.map(
              (piece) => indexFor(piece.position),
            ),
            afterClear: _motionCells(step.boardAfterClear),
            afterFall: _motionCells(step.boardAfterFall),
            afterRefill: _motionCells(step.boardAfterRefill),
            sealHits: [
              for (final hit in step.sealHits)
                DiscoveryMotionSealHit(
                  index: indexFor(hit.position),
                  layersBefore: hit.layersBefore,
                  layersAfter: hit.layersAfter,
                ),
            ],
            createdPowers: step.createdPowers.map(powerFor),
            activatedPowers: step.activatedPowers.map(powerFor),
            discoveries: [
              for (final target in step.discoveredTargets)
                DiscoveryMotionDiscovery(
                  index: indexFor(target.position),
                  block: _blockForTokenId(target.piece.id),
                ),
            ],
          ),
      ],
    );
  }

  List<DiscoveryMotionCell> _motionCells(DiscoveryBoard board) => [
    for (final position in board.positions)
      DiscoveryMotionCell(
        gem: board.pieceAt(position) == null
            ? null
            : _cellForPosition(board, position),
        sealKind: _sealKind(board.cellAt(position).buriedTarget?.kind),
        sealLayers: board.cellAt(position).sealLayers,
      ),
  ];

  DiscoverySealKind? _sealKind(DiscoveryPieceKind? kind) => switch (kind) {
    DiscoveryPieceKind.number => DiscoverySealKind.number,
    DiscoveryPieceKind.mathOperator => DiscoverySealKind.operatorSymbol,
    DiscoveryPieceKind.parenthesis => DiscoverySealKind.parenthesis,
    DiscoveryPieceKind.gem || null => null,
  };

  EquationToken _tokenForId(String id) => _puzzle.tokens.firstWhere(
    (token) => token.id == id,
    orElse: () => throw StateError('Puzzle token $id is missing.'),
  );

  DiscoveryEquationBlock _blockForTokenId(String id) {
    final token = _tokenForId(id);
    final kind = switch (token.kind) {
      EquationTokenKind.number => DiscoveryEquationBlockKind.number,
      EquationTokenKind.operator => DiscoveryEquationBlockKind.operatorSymbol,
      EquationTokenKind.leftParenthesis || EquationTokenKind.rightParenthesis =>
        DiscoveryEquationBlockKind.parenthesis,
    };
    return DiscoveryEquationBlock(id: id, label: token.label, kind: kind);
  }

  void _addDiscoveredToken(String id) {
    if (_stage.startingTokenIds.contains(id) ||
        _discoveredBlocks.any((block) => block.id == id)) {
      return;
    }
    _discoveredBlocks.add(_blockForTokenId(id));
  }

  void _refreshBoardCells() {
    final board = _engine.state.board;
    _boardCells
      ..clear()
      ..addAll([
        for (final position in board.positions)
          _cellForPosition(board, position),
      ]);
  }

  DiscoveryGemCell _cellForPosition(
    DiscoveryBoard board,
    DiscoveryPosition position,
  ) {
    final cell = board.cellAt(position);
    final piece = cell.piece!;
    return DiscoveryGemCell(
      id: piece.id,
      kind: _gemKind(piece.matchKey),
      sealLayers: cell.sealLayers,
      linePowerKind: switch (piece.linePower) {
        DiscoveryLinePower.row => DiscoveryLinePowerKind.row,
        DiscoveryLinePower.column => DiscoveryLinePowerKind.column,
        null => null,
      },
      sealKind: switch (cell.buriedTarget?.kind) {
        DiscoveryPieceKind.number => DiscoverySealKind.number,
        DiscoveryPieceKind.mathOperator => DiscoverySealKind.operatorSymbol,
        DiscoveryPieceKind.parenthesis => DiscoverySealKind.parenthesis,
        DiscoveryPieceKind.gem || null => null,
      },
    );
  }

  DiscoveryGemKind _gemKind(String matchKey) => switch (matchKey) {
    'A' => DiscoveryGemKind.berry,
    'B' => DiscoveryGemKind.ocean,
    'C' => DiscoveryGemKind.citrus,
    'D' => DiscoveryGemKind.grape,
    'E' => DiscoveryGemKind.leaf,
    _ => DiscoveryGemKind.sun,
  };

  DiscoveryPosition _positionForIndex(int index) =>
      DiscoveryPosition(index ~/ boardColumns, index % boardColumns);

  DiscoveryEquationBlock? _findBlock(
    List<DiscoveryEquationBlock> blocks,
    String id,
  ) {
    for (final block in blocks) {
      if (block.id == id) {
        return block;
      }
    }
    return null;
  }

  PuzzleMisconceptionCategory _misconceptionCategoryFor(
    PuzzleValidationResult result,
  ) {
    if (result.isCorrect) {
      throw ArgumentError.value(
        result,
        'result',
        'Correct results need no hint.',
      );
    }
    if (result.isStructureMismatch) {
      return PuzzleMisconceptionCategory.quantityRelationship;
    }
    return switch (result.reason) {
      PuzzleValidationReason.empty ||
      PuzzleValidationReason.missingRequiredToken =>
        PuzzleMisconceptionCategory.incompleteExpression,
      PuzzleValidationReason.duplicatedToken ||
      PuzzleValidationReason.unknownToken ||
      PuzzleValidationReason.distractorUsed =>
        PuzzleMisconceptionCategory.tokenSelection,
      PuzzleValidationReason.invalidSyntax =>
        PuzzleMisconceptionCategory.syntax,
      PuzzleValidationReason.wrongValue =>
        PuzzleMisconceptionCategory.operationOrder,
      PuzzleValidationReason.correct => throw StateError(
        'Correct results need no misconception category.',
      ),
    };
  }

  String _hintKindLabel(PuzzleHintKind kind) => switch (kind) {
    PuzzleHintKind.observation => '관찰',
    PuzzleHintKind.relationship => '관계',
    PuzzleHintKind.partialExpression => '부분 식',
  };

  String _nextDiscoveryInstruction(Set<String> collectedTargetIds) {
    for (final step in _runtime.tutorialSteps) {
      if (!collectedTargetIds.contains(step.targetId)) {
        return '${step.from.row + 1}행 ${step.from.column + 1}열 보석을 '
            '${step.to.row + 1}행 ${step.to.column + 1}열 보석과 바꾸세요.';
      }
    }
    if (_engine.state.isCompleted) return '필요한 블록을 모두 찾았어요. 오른쪽에서 식을 완성하세요.';
    if (_runtime.enableLinePowers &&
        _engine.state.requiredTargetIds.every(
          _engine.state.collectedTargetIds.contains,
        ))
      return '직선 파워를 인접 보석과 바꿔 활성하면 식을 확인할 수 있어요.';
    return _runtime.enableLinePowers
        ? '4개 매치로 파워를 만들고 인접 교환으로 한 줄을 타격하세요.'
        : _stage.matchDifficulty.maxSealLayers > 1
        ? '두 겹 봉인은 같은 칸에서 매치를 두 번 만들어 열어요.'
        : '봉인이 있는 칸에서 보석 3개를 연결해 조각을 찾아보세요.';
  }

  bool _isExpectedTutorialSwap(
    DiscoveryPosition from,
    DiscoveryPosition to,
    Set<String> collectedTargetIds,
  ) {
    if (_stage.assistRules.tutorialMode != StageTutorialMode.forced)
      return true;
    for (var index = 0; index < _runtime.tutorialSteps.length; index++) {
      if (collectedTargetIds.contains(_tutorialTargetIds[index])) {
        continue;
      }
      final step = _runtime.tutorialSteps[index];
      return (from == step.from && to == step.to) ||
          (from == step.to && to == step.from);
    }
    return true;
  }

  void _setFeedback(String message, DiscoveryFeedbackTone tone) {
    _feedbackMessage = message;
    _feedbackTone = tone;
  }
}
