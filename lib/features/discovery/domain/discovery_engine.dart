import 'discovery_models.dart';
import 'discovery_piece_source.dart';

class DiscoveryEngine {
  DiscoveryEngine({
    required DiscoveryBoard initialBoard,
    required Iterable<String> requiredTargetIds,
    required int moves,
    required DiscoveryPieceSource refillSource,
    this.enableLinePowers = false,
    this.requiredLinePowerActivations = 0,
  }) : _board = initialBoard,
       _requiredTargetIds = Set.unmodifiable(requiredTargetIds),
       _movesRemaining = moves,
       _refillSource = refillSource {
    if (moves < 0) {
      throw ArgumentError.value(moves, 'moves', 'Must not be negative.');
    }
    if (requiredLinePowerActivations < 0 ||
        (!enableLinePowers && requiredLinePowerActivations != 0)) {
      throw ArgumentError('Required line activations need enabled powers.');
    }
    if (!initialBoard.isFull) {
      throw ArgumentError('The initial discovery board must be full.');
    }
    if (!enableLinePowers &&
        initialBoard.visiblePieces.any((piece) => piece.linePower != null)) {
      throw ArgumentError('Initial powers require the line-power mechanic.');
    }
    _ensureUniqueVisibleIds(initialBoard);

    final buriedById = <String, DiscoveryPiece>{};
    for (final target in initialBoard.buriedTargets) {
      if (buriedById.containsKey(target.id)) {
        throw ArgumentError('Buried target ID ${target.id} is duplicated.');
      }
      buriedById[target.id] = target;
    }
    final missingTargets = _requiredTargetIds.difference(
      buriedById.keys.toSet(),
    );
    if (missingTargets.isNotEmpty) {
      throw ArgumentError(
        'Required targets are not buried on the board: $missingTargets',
      );
    }
    if (_findMatches(initialBoard).isNotEmpty) {
      throw ArgumentError(
        'The initial board must not contain an existing match.',
      );
    }
  }

  DiscoveryBoard _board;
  final Set<String> _requiredTargetIds;
  final DiscoveryPieceSource _refillSource;
  final Map<String, DiscoveryPiece> _collectedTargets = {};
  int _movesRemaining;
  final bool enableLinePowers;
  final int requiredLinePowerActivations;
  int _linePowerActivations = 0;
  DiscoveryGameState? _cachedState;

  DiscoveryGameState get state => _cachedState ??= _createState();

  DiscoveryTurnResult swap(DiscoveryPosition from, DiscoveryPosition to) {
    if (!_board.contains(from) || !_board.contains(to)) {
      return _unchangedResult(DiscoverySwapStatus.invalidPosition, from, to);
    }
    final currentState = state;
    if (!currentState.isCompleted && _movesRemaining == 0) {
      return _unchangedResult(DiscoverySwapStatus.noMovesRemaining, from, to);
    }
    if (currentState.isCompleted) {
      return _unchangedResult(DiscoverySwapStatus.alreadyCompleted, from, to);
    }
    if (!from.isAdjacentTo(to)) {
      return _unchangedResult(DiscoverySwapStatus.notAdjacent, from, to);
    }

    var candidate = _swapPieces(_board, from, to);
    var matches = _findMatches(candidate);
    if (enableLinePowers) {
      if (candidate.pieceAt(from)?.linePower != null) matches.add(from);
      if (candidate.pieceAt(to)?.linePower != null) matches.add(to);
    }
    if (matches.isEmpty) {
      return _unchangedResult(DiscoverySwapStatus.noMatch, from, to);
    }

    final nextMovesRemaining = _movesRemaining - 1;
    final nextCollectedTargets = Map<String, DiscoveryPiece>.of(
      _collectedTargets,
    );
    final cascades = <DiscoveryCascadeStep>[];
    final newlyDiscoveredTargets = <DiscoveryPiece>[];
    var cascadeIndex = 0;
    var nextLinePowerActivations = _linePowerActivations;

    while (matches.isNotEmpty) {
      if (cascadeIndex >= 100) {
        throw StateError('Cascade limit exceeded. Check the refill source.');
      }
      final created = enableLinePowers
          ? _createLinePowers(candidate, cascadeIndex == 0 ? [to, from] : [])
          : <DiscoveryPosition, DiscoveryPiece>{};
      final activated = <DiscoveryPowerEvent>[];
      if (enableLinePowers) _expandPowerHits(candidate, matches, activated);
      nextLinePowerActivations += activated.length;
      final orderedMatches = matches.toList()
        ..sort((left, right) {
          final rowOrder = left.row.compareTo(right.row);
          return rowOrder != 0 ? rowOrder : left.column.compareTo(right.column);
        });
      final cells = _mutableCells(candidate);
      final clearedPieces = <DiscoveryClearedPiece>[];
      final discoveredTargets = <DiscoveredTarget>[];
      final sealHits = <DiscoverySealHit>[];

      for (final position in orderedMatches) {
        final cell = cells[position.row][position.column];
        final piece = cell.piece;
        if (piece == null) {
          continue;
        }
        clearedPieces.add(
          DiscoveryClearedPiece(position: position, piece: piece),
        );
        final target = cell.buriedTarget;
        final remainingLayers = target == null ? 0 : cell.sealLayers - 1;
        if (target != null) {
          sealHits.add(
            DiscoverySealHit(
              position: position,
              layersBefore: cell.sealLayers,
              layersAfter: remainingLayers,
            ),
          );
          if (remainingLayers == 0) {
            discoveredTargets.add(
              DiscoveredTarget(position: position, piece: target),
            );
            if (!nextCollectedTargets.containsKey(target.id)) {
              nextCollectedTargets[target.id] = target;
              newlyDiscoveredTargets.add(target);
            }
          }
        }
        cells[position.row][position.column] = DiscoveryCell(
          piece: created[position],
          buriedTarget: remainingLayers > 0 ? target : null,
          sealLayers: remainingLayers,
        );
      }

      final boardAfterClear = DiscoveryBoard.fromCells(cells);
      final boardAfterFall = _applyGravity(boardAfterClear);
      final boardAfterRefill = _refill(boardAfterFall);
      cascades.add(
        DiscoveryCascadeStep(
          index: cascadeIndex,
          clearedPieces: clearedPieces,
          discoveredTargets: discoveredTargets,
          boardAfterClear: boardAfterClear,
          boardAfterFall: boardAfterFall,
          boardAfterRefill: boardAfterRefill,
          sealHits: sealHits,
          createdPowers: [
            for (final entry in created.entries)
              DiscoveryPowerEvent(
                position: entry.key,
                direction: entry.value.linePower!,
              ),
          ],
          activatedPowers: activated,
        ),
      );
      candidate = boardAfterRefill;
      matches = _findMatches(candidate);
      cascadeIndex += 1;
    }

    _board = candidate;
    _movesRemaining = nextMovesRemaining;
    _linePowerActivations = nextLinePowerActivations;
    _collectedTargets
      ..clear()
      ..addAll(nextCollectedTargets);
    _cachedState = null;
    return DiscoveryTurnResult(
      status: DiscoverySwapStatus.accepted,
      from: from,
      to: to,
      state: state,
      cascades: cascades,
      newlyDiscoveredTargets: newlyDiscoveredTargets,
    );
  }

  DiscoveryTurnResult _unchangedResult(
    DiscoverySwapStatus status,
    DiscoveryPosition from,
    DiscoveryPosition to,
  ) => DiscoveryTurnResult(status: status, from: from, to: to, state: state);

  DiscoveryGameState _createState() => DiscoveryGameState(
    board: _board,
    movesRemaining: _movesRemaining,
    requiredTargetIds: _requiredTargetIds,
    collectedTargets: _collectedTargets.values,
    hasAvailableMove: _hasAvailableMove(_board),
    linePowerActivations: _linePowerActivations,
    requiredLinePowerActivations: requiredLinePowerActivations,
  );

  DiscoveryBoard _swapPieces(
    DiscoveryBoard board,
    DiscoveryPosition from,
    DiscoveryPosition to,
  ) {
    final cells = _mutableCells(board);
    final fromCell = cells[from.row][from.column];
    final toCell = cells[to.row][to.column];
    cells[from.row][from.column] = DiscoveryCell(
      piece: toCell.piece,
      buriedTarget: fromCell.buriedTarget,
      sealLayers: fromCell.sealLayers,
    );
    cells[to.row][to.column] = DiscoveryCell(
      piece: fromCell.piece,
      buriedTarget: toCell.buriedTarget,
      sealLayers: toCell.sealLayers,
    );
    return DiscoveryBoard.fromCells(cells);
  }

  Set<DiscoveryPosition> _findMatches(DiscoveryBoard board) {
    final matches = <DiscoveryPosition>{};

    for (var row = 0; row < board.rowCount; row += 1) {
      var runStart = 0;
      for (var column = 1; column <= board.columnCount; column += 1) {
        final previousKey = board.cells[row][column - 1].piece?.matchKey;
        final currentKey = column < board.columnCount
            ? board.cells[row][column].piece?.matchKey
            : null;
        if (previousKey == null || previousKey != currentKey) {
          if (previousKey != null && column - runStart >= 3) {
            for (
              var matchedColumn = runStart;
              matchedColumn < column;
              matchedColumn += 1
            ) {
              matches.add(DiscoveryPosition(row, matchedColumn));
            }
          }
          runStart = column;
        }
      }
    }

    for (var column = 0; column < board.columnCount; column += 1) {
      var runStart = 0;
      for (var row = 1; row <= board.rowCount; row += 1) {
        final previousKey = board.cells[row - 1][column].piece?.matchKey;
        final currentKey = row < board.rowCount
            ? board.cells[row][column].piece?.matchKey
            : null;
        if (previousKey == null || previousKey != currentKey) {
          if (previousKey != null && row - runStart >= 3) {
            for (var matchedRow = runStart; matchedRow < row; matchedRow += 1) {
              matches.add(DiscoveryPosition(matchedRow, column));
            }
          }
          runStart = row;
        }
      }
    }

    return matches;
  }

  DiscoveryBoard _applyGravity(DiscoveryBoard board) {
    final cells = _mutableCells(board);
    for (var column = 0; column < board.columnCount; column += 1) {
      final fallingPieces = <DiscoveryPiece>[];
      for (var row = board.rowCount - 1; row >= 0; row -= 1) {
        final piece = cells[row][column].piece;
        if (piece != null) {
          fallingPieces.add(piece);
        }
        cells[row][column] = cells[row][column].withPiece(null);
      }
      var destinationRow = board.rowCount - 1;
      for (final piece in fallingPieces) {
        cells[destinationRow][column] = cells[destinationRow][column].withPiece(
          piece,
        );
        destinationRow -= 1;
      }
    }
    return DiscoveryBoard.fromCells(cells);
  }

  /// One long run creates one power. The moved gem is preferred; cascades use
  /// the final run cell. Existing powers activate rather than being replaced.
  Map<DiscoveryPosition, DiscoveryPiece> _createLinePowers(
    DiscoveryBoard board,
    List<DiscoveryPosition> preferred,
  ) {
    final result = <DiscoveryPosition, DiscoveryPiece>{};
    void inspect(List<DiscoveryPosition> line, DiscoveryLinePower direction) {
      var start = 0;
      for (var end = 1; end <= line.length; end++) {
        final key = board.pieceAt(line[end - 1])?.matchKey;
        final next = end < line.length
            ? board.pieceAt(line[end])?.matchKey
            : null;
        if (key == null || key != next) {
          if (key != null && end - start >= 4) {
            final run = line.sublist(start, end);
            if (!run.any((p) => board.pieceAt(p)?.linePower != null)) {
              final anchor =
                  preferred.where(run.contains).firstOrNull ?? run.last;
              result.putIfAbsent(
                anchor,
                () => board.pieceAt(anchor)!.withLinePower(direction),
              );
            }
          }
          start = end;
        }
      }
    }

    for (var row = 0; row < board.rowCount; row++) {
      inspect([
        for (var column = 0; column < board.columnCount; column++)
          DiscoveryPosition(row, column),
      ], DiscoveryLinePower.row);
    }
    for (var column = 0; column < board.columnCount; column++) {
      inspect([
        for (var row = 0; row < board.rowCount; row++)
          DiscoveryPosition(row, column),
      ], DiscoveryLinePower.column);
    }
    return result;
  }

  /// A seal receives at most one hit per cascade, even where lines intersect.
  /// Chained powers are processed deterministically in row-major order.
  void _expandPowerHits(
    DiscoveryBoard board,
    Set<DiscoveryPosition> hits,
    List<DiscoveryPowerEvent> activations,
  ) {
    final processed = <DiscoveryPosition>{};
    while (true) {
      final pending =
          hits
              .where(
                (p) =>
                    !processed.contains(p) &&
                    board.pieceAt(p)?.linePower != null,
              )
              .toList()
            ..sort(
              (a, b) => a.row != b.row
                  ? a.row.compareTo(b.row)
                  : a.column.compareTo(b.column),
            );
      if (pending.isEmpty) break;
      for (final position in pending) {
        processed.add(position);
        final direction = board.pieceAt(position)!.linePower!;
        activations.add(
          DiscoveryPowerEvent(position: position, direction: direction),
        );
        if (direction == DiscoveryLinePower.row) {
          for (var column = 0; column < board.columnCount; column++) {
            hits.add(DiscoveryPosition(position.row, column));
          }
        } else {
          for (var row = 0; row < board.rowCount; row++) {
            hits.add(DiscoveryPosition(row, position.column));
          }
        }
      }
    }
  }

  DiscoveryBoard _refill(DiscoveryBoard board) {
    final cells = _mutableCells(board);
    for (var row = 0; row < board.rowCount; row += 1) {
      for (var column = 0; column < board.columnCount; column += 1) {
        if (cells[row][column].piece == null) {
          final position = DiscoveryPosition(row, column);
          cells[row][column] = cells[row][column].withPiece(
            _refillSource.nextPiece(position),
          );
        }
      }
    }
    final refilled = DiscoveryBoard.fromCells(cells);
    _ensureUniqueVisibleIds(refilled);
    return refilled;
  }

  bool _hasAvailableMove(DiscoveryBoard board) {
    if (enableLinePowers &&
        board.visiblePieces.any((piece) => piece.linePower != null))
      return true;
    for (final position in board.positions) {
      final right = DiscoveryPosition(position.row, position.column + 1);
      if (board.contains(right) &&
          _findMatches(_swapPieces(board, position, right)).isNotEmpty) {
        return true;
      }
      final below = DiscoveryPosition(position.row + 1, position.column);
      if (board.contains(below) &&
          _findMatches(_swapPieces(board, position, below)).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  List<List<DiscoveryCell>> _mutableCells(DiscoveryBoard board) => [
    for (final row in board.cells) [...row],
  ];

  void _ensureUniqueVisibleIds(DiscoveryBoard board) {
    final seen = <String>{};
    for (final piece in board.visiblePieces) {
      if (!seen.add(piece.id)) {
        throw StateError('Visible piece ID ${piece.id} is duplicated.');
      }
    }
  }
}
