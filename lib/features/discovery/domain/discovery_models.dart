enum DiscoveryPieceKind { gem, number, mathOperator, parenthesis }

enum DiscoveryLinePower { row, column }

class DiscoveryBoardConfig {
  const DiscoveryBoardConfig({this.rows = 6, this.columns = 6})
    : assert(rows >= 3),
      assert(columns >= 3);

  static const compactPhone = DiscoveryBoardConfig(rows: 5, columns: 5);
  static const standardPhone = DiscoveryBoardConfig();
  static const widePhone = DiscoveryBoardConfig(columns: 7);

  final int rows;
  final int columns;
}

class DiscoveryPosition {
  const DiscoveryPosition(this.row, this.column);

  final int row;
  final int column;

  bool isAdjacentTo(DiscoveryPosition other) {
    final rowDistance = (row - other.row).abs();
    final columnDistance = (column - other.column).abs();
    return rowDistance + columnDistance == 1;
  }

  @override
  bool operator ==(Object other) =>
      other is DiscoveryPosition && row == other.row && column == other.column;

  @override
  int get hashCode => Object.hash(row, column);

  @override
  String toString() => '($row, $column)';
}

class DiscoveryPiece {
  const DiscoveryPiece({
    required this.id,
    required this.kind,
    required this.label,
    required this.matchKey,
    this.linePower,
  }) : assert(id != ''),
       assert(label != ''),
       assert(matchKey != '');

  const DiscoveryPiece.gem({required String id, required String gemKey})
    : this(
        id: id,
        kind: DiscoveryPieceKind.gem,
        label: gemKey,
        matchKey: gemKey,
      );

  const DiscoveryPiece.numberToken({required String id, required String label})
    : this(
        id: id,
        kind: DiscoveryPieceKind.number,
        label: label,
        matchKey: 'number:$label',
      );

  const DiscoveryPiece.operatorToken({
    required String id,
    required String label,
  }) : this(
         id: id,
         kind: DiscoveryPieceKind.mathOperator,
         label: label,
         matchKey: 'operator:$label',
       );

  const DiscoveryPiece.parenthesisToken({
    required String id,
    required String label,
  }) : this(
         id: id,
         kind: DiscoveryPieceKind.parenthesis,
         label: label,
         matchKey: 'parenthesis:$label',
       );

  final String id;
  final DiscoveryPieceKind kind;
  final String label;
  final String matchKey;
  final DiscoveryLinePower? linePower;

  DiscoveryPiece withLinePower(DiscoveryLinePower direction) => DiscoveryPiece(
    id: '$id-power',
    kind: kind,
    label: label,
    matchKey: matchKey,
    linePower: direction,
  );

  bool get isMathToken => kind != DiscoveryPieceKind.gem;

  @override
  bool operator ==(Object other) =>
      other is DiscoveryPiece &&
      id == other.id &&
      kind == other.kind &&
      label == other.label &&
      matchKey == other.matchKey &&
      linePower == other.linePower;

  @override
  int get hashCode => Object.hash(id, kind, label, matchKey, linePower);

  @override
  String toString() => '$label<$id>';
}

class DiscoveryCell {
  const DiscoveryCell({required this.piece, this.buriedTarget, int? sealLayers})
    : sealLayers = sealLayers ?? (buriedTarget == null ? 0 : 1);

  final DiscoveryPiece? piece;
  final DiscoveryPiece? buriedTarget;
  final int sealLayers;

  DiscoveryCell withPiece(DiscoveryPiece? value) => DiscoveryCell(
    piece: value,
    buriedTarget: buriedTarget,
    sealLayers: sealLayers,
  );

  DiscoveryCell withoutBuriedTarget() => DiscoveryCell(piece: piece);
}

class DiscoveryBoard {
  factory DiscoveryBoard.fromRows(
    List<List<DiscoveryPiece>> rows, {
    DiscoveryBoardConfig? config,
    Map<DiscoveryPosition, DiscoveryPiece> buriedTargets = const {},
    Map<DiscoveryPosition, int> sealLayers = const {},
  }) {
    final cells = <List<DiscoveryCell>>[
      for (var row = 0; row < rows.length; row += 1)
        <DiscoveryCell>[
          for (var column = 0; column < rows[row].length; column += 1)
            DiscoveryCell(
              piece: rows[row][column],
              buriedTarget: buriedTargets[DiscoveryPosition(row, column)],
              sealLayers: sealLayers[DiscoveryPosition(row, column)],
            ),
        ],
    ];
    final board = DiscoveryBoard.fromCells(cells);
    if (config != null &&
        (config.rows != board.rowCount ||
            config.columns != board.columnCount)) {
      throw ArgumentError(
        'Board dimensions ${board.rowCount}x${board.columnCount} do not '
        'match config ${config.rows}x${config.columns}.',
      );
    }
    return board;
  }

  factory DiscoveryBoard.fromCells(List<List<DiscoveryCell>> cells) {
    if (cells.length < 3) {
      throw ArgumentError.value(cells.length, 'cells', 'Need at least 3 rows.');
    }
    final columnCount = cells.first.length;
    if (columnCount < 3) {
      throw ArgumentError.value(
        columnCount,
        'cells',
        'Need at least 3 columns.',
      );
    }
    if (cells.any((row) => row.length != columnCount)) {
      throw ArgumentError('Every board row must have the same length.');
    }

    for (final row in cells) {
      for (final cell in row) {
        if (cell.piece?.linePower != null &&
            cell.piece?.kind != DiscoveryPieceKind.gem) {
          throw ArgumentError('Only gems can carry a line power.');
        }
        final target = cell.buriedTarget;
        if ((target == null && cell.sealLayers != 0) ||
            (target != null && cell.sealLayers < 1)) {
          throw ArgumentError('A seal must have a target and positive layers.');
        }
        if (target != null && !target.isMathToken) {
          throw ArgumentError(
            'Buried target ${target.id} must be a number or operator.',
          );
        }
      }
    }

    return DiscoveryBoard._(cells);
  }

  DiscoveryBoard._(List<List<DiscoveryCell>> cells)
    : _cells = List<List<DiscoveryCell>>.unmodifiable(
        cells.map(List<DiscoveryCell>.unmodifiable),
      );

  final List<List<DiscoveryCell>> _cells;

  int get rowCount => _cells.length;
  int get columnCount => _cells.first.length;
  List<List<DiscoveryCell>> get cells => _cells;

  bool contains(DiscoveryPosition position) =>
      position.row >= 0 &&
      position.row < rowCount &&
      position.column >= 0 &&
      position.column < columnCount;

  DiscoveryCell cellAt(DiscoveryPosition position) {
    if (!contains(position)) {
      throw RangeError('Position $position is outside the board.');
    }
    return _cells[position.row][position.column];
  }

  DiscoveryPiece? pieceAt(DiscoveryPosition position) => cellAt(position).piece;

  Iterable<DiscoveryPosition> get positions sync* {
    for (var row = 0; row < rowCount; row += 1) {
      for (var column = 0; column < columnCount; column += 1) {
        yield DiscoveryPosition(row, column);
      }
    }
  }

  Iterable<DiscoveryPiece> get visiblePieces sync* {
    for (final position in positions) {
      final piece = pieceAt(position);
      if (piece != null) {
        yield piece;
      }
    }
  }

  Iterable<DiscoveryPiece> get buriedTargets sync* {
    for (final position in positions) {
      final target = cellAt(position).buriedTarget;
      if (target != null) {
        yield target;
      }
    }
  }

  bool get isFull => visiblePieces.length == rowCount * columnCount;
}

class DiscoveryClearedPiece {
  const DiscoveryClearedPiece({required this.position, required this.piece});

  final DiscoveryPosition position;
  final DiscoveryPiece piece;
}

class DiscoveredTarget {
  const DiscoveredTarget({required this.position, required this.piece});

  final DiscoveryPosition position;
  final DiscoveryPiece piece;
}

class DiscoverySealHit {
  const DiscoverySealHit({
    required this.position,
    required this.layersBefore,
    required this.layersAfter,
  });
  final DiscoveryPosition position;
  final int layersBefore;
  final int layersAfter;
}

class DiscoveryPowerEvent {
  const DiscoveryPowerEvent({required this.position, required this.direction});
  final DiscoveryPosition position;
  final DiscoveryLinePower direction;
}

class DiscoveryCascadeStep {
  DiscoveryCascadeStep({
    required this.index,
    required Iterable<DiscoveryClearedPiece> clearedPieces,
    required Iterable<DiscoveredTarget> discoveredTargets,
    required this.boardAfterClear,
    required this.boardAfterFall,
    required this.boardAfterRefill,
    Iterable<DiscoverySealHit> sealHits = const [],
    Iterable<DiscoveryPowerEvent> createdPowers = const [],
    Iterable<DiscoveryPowerEvent> activatedPowers = const [],
  }) : clearedPieces = List.unmodifiable(clearedPieces),
       discoveredTargets = List.unmodifiable(discoveredTargets),
       sealHits = List.unmodifiable(sealHits),
       createdPowers = List.unmodifiable(createdPowers),
       activatedPowers = List.unmodifiable(activatedPowers);

  final int index;
  final List<DiscoveryClearedPiece> clearedPieces;
  final List<DiscoveredTarget> discoveredTargets;
  final DiscoveryBoard boardAfterClear;
  final DiscoveryBoard boardAfterFall;
  final DiscoveryBoard boardAfterRefill;
  final List<DiscoverySealHit> sealHits;
  final List<DiscoveryPowerEvent> createdPowers;
  final List<DiscoveryPowerEvent> activatedPowers;
}

enum DiscoverySwapStatus {
  accepted,
  invalidPosition,
  notAdjacent,
  noMatch,
  noMovesRemaining,
  alreadyCompleted,
}

class DiscoveryGameState {
  DiscoveryGameState({
    required this.board,
    required this.movesRemaining,
    required Iterable<String> requiredTargetIds,
    required Iterable<DiscoveryPiece> collectedTargets,
    required this.hasAvailableMove,
    this.linePowerActivations = 0,
    this.requiredLinePowerActivations = 0,
  }) : requiredTargetIds = Set.unmodifiable(requiredTargetIds),
       collectedTargets = List.unmodifiable(collectedTargets);

  final DiscoveryBoard board;
  final int movesRemaining;
  final Set<String> requiredTargetIds;
  final List<DiscoveryPiece> collectedTargets;
  late final Set<String> collectedTargetIds = Set.unmodifiable(
    collectedTargets.map((piece) => piece.id),
  );
  final bool hasAvailableMove;
  final int linePowerActivations;
  final int requiredLinePowerActivations;

  bool get isCompleted =>
      requiredTargetIds.every(collectedTargetIds.contains) &&
      linePowerActivations >= requiredLinePowerActivations;

  bool get isOutOfMoves => !isCompleted && movesRemaining == 0;

  bool get isDeadBoard =>
      !isCompleted && movesRemaining > 0 && !hasAvailableMove;
}

class DiscoveryTurnResult {
  DiscoveryTurnResult({
    required this.status,
    required this.from,
    required this.to,
    required this.state,
    Iterable<DiscoveryCascadeStep> cascades = const [],
    Iterable<DiscoveryPiece> newlyDiscoveredTargets = const [],
  }) : cascades = List.unmodifiable(cascades),
       newlyDiscoveredTargets = List.unmodifiable(newlyDiscoveredTargets);

  final DiscoverySwapStatus status;
  final DiscoveryPosition from;
  final DiscoveryPosition to;
  final DiscoveryGameState state;
  final List<DiscoveryCascadeStep> cascades;
  final List<DiscoveryPiece> newlyDiscoveredTargets;

  bool get isAccepted => status == DiscoverySwapStatus.accepted;
}
