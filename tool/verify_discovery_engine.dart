import 'dart:io';

import '../lib/features/discovery/data/tutorial_discovery_fixture.dart';
import '../lib/features/discovery/domain/discovery_engine.dart';
import '../lib/features/discovery/domain/discovery_models.dart';
import '../lib/features/discovery/domain/discovery_piece_source.dart';

void main() {
  const standardConfig = DiscoveryBoardConfig.standardPhone;
  final initialBoard = _playableBoard(standardConfig);
  _expect(initialBoard.rowCount == 6, 'the standard board should have 6 rows');
  _expect(
    initialBoard.columnCount == 6,
    'the standard board should have 6 columns',
  );

  final refillPieces = _controlledRefill();
  final engine = DiscoveryEngine(
    initialBoard: initialBoard,
    requiredTargetIds: const {'target-four', 'target-times'},
    moves: 8,
    refillSource: QueuedPieceSource(pieces: refillPieces),
  );
  _expect(
    identical(engine.state, engine.state),
    'unchanged engine state should be cached',
  );
  _expect(engine.state.hasAvailableMove, 'the sample board should be playable');

  final accepted = engine.swap(
    const DiscoveryPosition(0, 1),
    const DiscoveryPosition(1, 1),
  );
  _expect(accepted.isAccepted, 'the intended adjacent swap should be accepted');
  _expect(
    accepted.state.movesRemaining == 7,
    'an accepted swap consumes one move',
  );
  _expect(
    accepted.cascades.length == 1,
    'the controlled refill should settle once',
  );
  _expect(
    accepted.cascades.single.clearedPieces.length == 6,
    'two three-piece matches should clear six gems',
  );
  _expect(
    accepted.newlyDiscoveredTargets
        .map((piece) => piece.id)
        .toSet()
        .containsAll(const {'target-four', 'target-times'}),
    'clearing covered cells should discover the required math tokens',
  );
  _expect(
    accepted.state.isCompleted,
    'collecting both targets completes the goal',
  );

  final invalidEngine = DiscoveryEngine(
    initialBoard: _playableBoard(standardConfig),
    requiredTargetIds: const {'target-four'},
    moves: 8,
    refillSource: SeededGemPieceSource(seed: 1, idPrefix: 'invalid-refill'),
  );
  final beforeInvalidSwap = _boardSignature(invalidEngine.state.board);
  final invalid = invalidEngine.swap(
    const DiscoveryPosition(5, 4),
    const DiscoveryPosition(5, 5),
  );
  _expect(
    invalid.status == DiscoverySwapStatus.noMatch,
    'an adjacent swap without a match should rebound',
  );
  _expect(
    invalid.state.movesRemaining == 8,
    'a rebounded swap should cost no move',
  );
  _expect(
    _boardSignature(invalid.state.board) == beforeInvalidSwap,
    'a rebounded swap should preserve the board',
  );

  final firstSeededResult = _runSeededTurn(seed: 2026, prefix: 'same');
  final secondSeededResult = _runSeededTurn(seed: 2026, prefix: 'same');
  _expect(
    _boardSignature(firstSeededResult.state.board) ==
        _boardSignature(secondSeededResult.state.board),
    'the same seed should produce the same refill board',
  );

  final deadBoard = _deadBoard(standardConfig);
  final deadEngine = DiscoveryEngine(
    initialBoard: deadBoard,
    requiredTargetIds: const {'unreachable-target'},
    moves: 5,
    refillSource: SeededGemPieceSource(seed: 7),
  );
  _expect(
    !deadEngine.state.hasAvailableMove,
    'the unique-key board has no match',
  );
  _expect(
    deadEngine.state.isDeadBoard,
    'an unplayable board should be detected',
  );

  final compactEngine = DiscoveryEngine(
    initialBoard: _playableBoard(DiscoveryBoardConfig.compactPhone),
    requiredTargetIds: const {'target-four'},
    moves: 6,
    refillSource: QueuedPieceSource(pieces: _controlledRefill()),
  );
  final compactTurn = compactEngine.swap(
    const DiscoveryPosition(0, 1),
    const DiscoveryPosition(1, 1),
  );
  _expect(
    compactTurn.isAccepted &&
        compactTurn.state.board.rowCount == 5 &&
        compactTurn.state.board.columnCount == 5,
    'a 5x5 compact board should support the same swap flow',
  );

  final wideBoard = _deadBoard(DiscoveryBoardConfig.widePhone);
  _expect(
    wideBoard.rowCount == 6 && wideBoard.columnCount == 7,
    'the board model should also support a 6x7 layout',
  );

  _verifyProgressivePuzzle(DiscoveryBoardConfig.compactPhone);
  _verifyProgressivePuzzle(DiscoveryBoardConfig.standardPhone);
  _verifyProgressivePuzzle(DiscoveryBoardConfig.widePhone);
  _verifyAtomicVisibleState(DiscoveryBoardConfig.standardPhone);

  const parenthesis = DiscoveryPiece.parenthesisToken(
    id: 'parenthesis-left',
    label: '(',
  );
  _expect(
    parenthesis.kind == DiscoveryPieceKind.parenthesis,
    'parentheses should preserve their discovery piece kind',
  );

  stdout.writeln('Discovery engine verification passed.');
}

void _verifyProgressivePuzzle(DiscoveryBoardConfig config) {
  final engine = DiscoveryEngine(
    initialBoard: DiscoveryTutorialFixture.build(
      config: config,
      timesTarget: const DiscoveryPiece.operatorToken(
        id: 'target-times',
        label: '×',
      ),
      plusTarget: const DiscoveryPiece.operatorToken(
        id: 'target-plus',
        label: '+',
      ),
      twoTarget: const DiscoveryPiece.numberToken(id: 'target-two', label: '2'),
    ),
    requiredTargetIds: const {'target-times', 'target-plus', 'target-two'},
    moves: 12,
    refillSource: QueuedPieceSource(
      pieces: DiscoveryTutorialFixture.refillPieces(
        idPrefix: 'progressive-refill',
      ),
    ),
  );
  const targetIdByFixtureId = {
    'p1-times': 'target-times',
    'p1-plus': 'target-plus',
    'p1-n2': 'target-two',
  };

  for (
    var index = 0;
    index < DiscoveryTutorialFixture.steps.length;
    index += 1
  ) {
    final step = DiscoveryTutorialFixture.steps[index];
    final expectedTargetId = targetIdByFixtureId[step.targetId]!;
    final result = engine.swap(step.from, step.to);
    _expect(
      result.isAccepted,
      '${config.rows}x${config.columns} progressive swap ${index + 1} should be accepted',
    );
    _expect(
      result.newlyDiscoveredTargets.map((piece) => piece.id).toSet().length ==
              1 &&
          result.newlyDiscoveredTargets.single.id == expectedTargetId,
      'progressive swap ${index + 1} should discover only $expectedTargetId',
    );
    _expect(
      result.state.movesRemaining == 11 - index,
      'each progressive match should consume one move',
    );
    _expect(
      result.state.isCompleted ==
          (index == DiscoveryTutorialFixture.steps.length - 1),
      'the goal should complete only after the third discovery',
    );
  }
}

void _verifyAtomicVisibleState(DiscoveryBoardConfig config) {
  final engine = DiscoveryEngine(
    initialBoard: _playableBoard(config),
    requiredTargetIds: const {'target-four'},
    moves: 8,
    refillSource: QueuedPieceSource(pieces: const []),
  );
  final before = engine.state;
  Object? failure;
  try {
    engine.swap(const DiscoveryPosition(0, 1), const DiscoveryPosition(1, 1));
  } on Object catch (error) {
    failure = error;
  }
  _expect(failure is StateError, 'an empty refill source should fail clearly');
  final after = engine.state;
  _expect(
    identical(before, after) &&
        after.movesRemaining == 8 &&
        after.collectedTargets.isEmpty &&
        _boardSignature(before.board) == _boardSignature(after.board),
    'a refill failure should not partially commit visible game state',
  );
}

DiscoveryTurnResult _runSeededTurn({
  required int seed,
  required String prefix,
}) {
  final engine = DiscoveryEngine(
    initialBoard: _playableBoard(DiscoveryBoardConfig.standardPhone),
    requiredTargetIds: const {'target-four'},
    moves: 8,
    refillSource: SeededGemPieceSource(seed: seed, idPrefix: prefix),
  );
  return engine.swap(
    const DiscoveryPosition(0, 1),
    const DiscoveryPosition(1, 1),
  );
}

DiscoveryBoard _playableBoard(DiscoveryBoardConfig config) {
  const keys = [
    ['A', 'B', 'A', 'C', 'D', 'E'],
    ['B', 'A', 'B', 'D', 'E', 'C'],
    ['C', 'D', 'C', 'E', 'A', 'B'],
    ['D', 'E', 'D', 'A', 'B', 'C'],
    ['E', 'C', 'E', 'B', 'C', 'D'],
    ['C', 'D', 'A', 'C', 'D', 'E'],
  ];
  if (config.rows > keys.length || config.columns > keys.first.length) {
    throw ArgumentError('The playable fixture supports boards up to 6x6.');
  }
  final rows = <List<DiscoveryPiece>>[
    for (var row = 0; row < config.rows; row += 1)
      <DiscoveryPiece>[
        for (var column = 0; column < config.columns; column += 1)
          DiscoveryPiece.gem(
            id: 'initial-$row-$column',
            gemKey: keys[row][column],
          ),
      ],
  ];
  return DiscoveryBoard.fromRows(
    rows,
    config: config,
    buriedTargets: {
      const DiscoveryPosition(0, 0): const DiscoveryPiece.numberToken(
        id: 'target-four',
        label: '4',
      ),
      const DiscoveryPosition(1, 0): const DiscoveryPiece.operatorToken(
        id: 'target-times',
        label: '×',
      ),
    },
  );
}

List<DiscoveryPiece> _controlledRefill() {
  const keys = ['A', 'B', 'C', 'B', 'C', 'D'];
  return [
    for (var index = 0; index < keys.length; index += 1)
      DiscoveryPiece.gem(id: 'controlled-$index', gemKey: keys[index]),
  ];
}

DiscoveryBoard _deadBoard(DiscoveryBoardConfig config) {
  final rows = <List<DiscoveryPiece>>[
    for (var row = 0; row < config.rows; row += 1)
      <DiscoveryPiece>[
        for (var column = 0; column < config.columns; column += 1)
          DiscoveryPiece.gem(
            id: 'dead-$row-$column',
            gemKey: 'unique-$row-$column',
          ),
      ],
  ];
  return DiscoveryBoard.fromRows(
    rows,
    config: config,
    buriedTargets: {
      const DiscoveryPosition(0, 0): const DiscoveryPiece.numberToken(
        id: 'unreachable-target',
        label: '9',
      ),
    },
  );
}

String _boardSignature(DiscoveryBoard board) => [
  for (final row in board.cells)
    [
      for (final cell in row) '${cell.piece?.id}:${cell.piece?.matchKey}',
    ].join(','),
].join('|');

void _expect(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}
