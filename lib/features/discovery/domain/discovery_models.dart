enum DiscoveryPieceKind { gem, number, mathOperator, parenthesis }

/// Historical name retained for checkpoints; burst/color extend the family.
enum DiscoveryLinePower { row, column, burst, color }

enum DiscoveryPowerCombination {
  lineLine,
  lineBurst,
  burstBurst,
  colorGem,
  colorLine,
  colorBurst,
  colorColor,
}

class DiscoveryBoardConfig {
  const DiscoveryBoardConfig({this.rows = 6, this.columns = 6})
    : assert(rows >= 3),
      assert(columns >= 3);

  static const compactPhone = DiscoveryBoardConfig(rows: 5, columns: 5);
  static const standardPhone = DiscoveryBoardConfig();
  static const widePhone = DiscoveryBoardConfig(columns: 7);
  static const densePhone = DiscoveryBoardConfig(rows: 7, columns: 7);

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
    this.carriedTarget,
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

  /// A falling equation fragment rides a normal matchable gem. It is awarded
  /// only when that gem is cleared, never merely when it enters the board.
  final DiscoveryPiece? carriedTarget;

  DiscoveryPiece withCarriedTarget(DiscoveryPiece target) => DiscoveryPiece(
    id: id,
    kind: kind,
    label: label,
    matchKey: matchKey,
    linePower: linePower,
    carriedTarget: target,
  );

  DiscoveryPiece withLinePower(DiscoveryLinePower direction) => DiscoveryPiece(
    id: '$id-power',
    kind: kind,
    label: label,
    matchKey: matchKey,
    linePower: direction,
    carriedTarget: carriedTarget,
  );

  bool get isMathToken => kind != DiscoveryPieceKind.gem;

  @override
  bool operator ==(Object other) =>
      other is DiscoveryPiece &&
      id == other.id &&
      kind == other.kind &&
      label == other.label &&
      matchKey == other.matchKey &&
      linePower == other.linePower &&
      carriedTarget == other.carriedTarget;

  @override
  int get hashCode =>
      Object.hash(id, kind, label, matchKey, linePower, carriedTarget);

  @override
  String toString() => '$label<$id>';
}

class DiscoveryCell {
  const DiscoveryCell({
    required this.piece,
    this.buriedTarget,
    int? sealLayers,
    this.blockerLayers = 0,
    this.iceLayers = 0,
  }) : sealLayers = sealLayers ?? (buriedTarget == null ? 0 : 1);

  final DiscoveryPiece? piece;
  final DiscoveryPiece? buriedTarget;
  final int sealLayers;

  /// Stationary cover: prevents swapping, matching and falling through it.
  /// Adjacent matches and direct power hits damage it once per cascade.
  final int blockerLayers;

  /// Ice anchors the gem and its fragment. Adjacent matches or power hits
  /// break one layer per cascade; the last layer awards the hidden fragment.
  final int iceLayers;

  DiscoveryCell withPiece(DiscoveryPiece? value) => DiscoveryCell(
    piece: value,
    buriedTarget: buriedTarget,
    sealLayers: sealLayers,
    blockerLayers: blockerLayers,
    iceLayers: iceLayers,
  );

  DiscoveryCell withoutBuriedTarget() =>
      DiscoveryCell(piece: piece, blockerLayers: blockerLayers);
}

class DiscoveryBoard {
  factory DiscoveryBoard.fromRows(
    List<List<DiscoveryPiece>> rows, {
    DiscoveryBoardConfig? config,
    Map<DiscoveryPosition, DiscoveryPiece> buriedTargets = const {},
    Map<DiscoveryPosition, int> sealLayers = const {},
    Map<DiscoveryPosition, int> blockerLayers = const {},
    Map<DiscoveryPosition, int> iceLayers = const {},
  }) {
    final cells = <List<DiscoveryCell>>[
      for (var row = 0; row < rows.length; row += 1)
        <DiscoveryCell>[
          for (var column = 0; column < rows[row].length; column += 1)
            DiscoveryCell(
              piece: rows[row][column],
              buriedTarget: buriedTargets[DiscoveryPosition(row, column)],
              sealLayers: sealLayers[DiscoveryPosition(row, column)],
              blockerLayers: blockerLayers[DiscoveryPosition(row, column)] ?? 0,
              iceLayers: iceLayers[DiscoveryPosition(row, column)] ?? 0,
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
        if (cell.iceLayers < 0 ||
            cell.iceLayers > 0 &&
                (cell.piece == null ||
                    cell.buriedTarget == null ||
                    cell.blockerLayers > 0 ||
                    cell.piece!.linePower != null ||
                    cell.piece!.carriedTarget != null)) {
          throw ArgumentError(
            'Ice needs one hidden fragment and an ordinary gem.',
          );
        }
        if (cell.piece?.carriedTarget case final target?) {
          if (cell.piece!.kind != DiscoveryPieceKind.gem ||
              !target.isMathToken ||
              target.carriedTarget != null) {
            throw ArgumentError(
              'A fragment must ride a gem and cannot contain another fragment.',
            );
          }
        }
        if (cell.blockerLayers < 0 ||
            cell.blockerLayers > 0 && cell.piece == null) {
          throw ArgumentError(
            'A blocker needs a gem and nonnegative durability.',
          );
        }
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
  bool canSwapAt(DiscoveryPosition position) =>
      contains(position) &&
      cellAt(position).blockerLayers == 0 &&
      cellAt(position).iceLayers == 0 &&
      pieceAt(position) != null;
  String? matchKeyAt(DiscoveryPosition position) =>
      cellAt(position).blockerLayers > 0 ||
          cellAt(position).iceLayers > 0 ||
          pieceAt(position)?.linePower == DiscoveryLinePower.color
      ? null
      : pieceAt(position)?.matchKey;

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
  const DiscoveryPowerEvent({
    required this.position,
    required this.direction,
    this.combination,
    this.affectedPositions = const [],
  });
  final DiscoveryPosition position;
  final DiscoveryLinePower direction;
  final DiscoveryPowerCombination? combination;
  final List<DiscoveryPosition> affectedPositions;
}

class DiscoveryBlockerHit {
  const DiscoveryBlockerHit({
    required this.position,
    required this.layersBefore,
    required this.layersAfter,
  });
  final DiscoveryPosition position;
  final int layersBefore;
  final int layersAfter;
}

enum DiscoveryObjectiveKind { color, ice, blockers, moves }

class DiscoveryObjective {
  const DiscoveryObjective({
    required this.id,
    required this.label,
    required this.kind,
    required this.goal,
    this.matchKey,
    this.rewardTarget,
  });
  final String id;
  final String label;
  final DiscoveryObjectiveKind kind;
  final int goal;
  final String? matchKey;

  /// Optional fragment awarded when this objective is completed.
  final DiscoveryPiece? rewardTarget;
}

class DiscoveryTargetDrop {
  const DiscoveryTargetDrop({
    required this.target,
    this.afterMoves = 2,
    this.column,
    this.requiredObjectiveIds = const {},
  });
  final DiscoveryPiece target;
  final int afterMoves;
  final int? column;
  final Set<String> requiredObjectiveIds;
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
    Iterable<DiscoveryBlockerHit> blockerHits = const [],
    Iterable<DiscoverySealHit> iceHits = const [],
  }) : clearedPieces = List.unmodifiable(clearedPieces),
       discoveredTargets = List.unmodifiable(discoveredTargets),
       sealHits = List.unmodifiable(sealHits),
       createdPowers = List.unmodifiable(createdPowers),
       activatedPowers = List.unmodifiable(activatedPowers),
       blockerHits = List.unmodifiable(blockerHits),
       iceHits = List.unmodifiable(iceHits);

  final int index;
  final List<DiscoveryClearedPiece> clearedPieces;
  final List<DiscoveredTarget> discoveredTargets;
  final DiscoveryBoard boardAfterClear;
  final DiscoveryBoard boardAfterFall;
  final DiscoveryBoard boardAfterRefill;
  final List<DiscoverySealHit> sealHits;
  final List<DiscoveryPowerEvent> createdPowers;
  final List<DiscoveryPowerEvent> activatedPowers;
  final List<DiscoveryBlockerHit> blockerHits;
  final List<DiscoverySealHit> iceHits;
}

enum DiscoverySwapStatus {
  accepted,
  invalidPosition,
  notAdjacent,
  noMatch,
  noMovesRemaining,
  alreadyCompleted,
  blocked,
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
    Map<DiscoveryLinePower, int> powerActivations = const {},
    this.requiredPowerKind,
    this.combinationActivations = 0,
    this.requiredCombinationActivations = 0,
    this.blockersCleared = 0,
    this.requiredBlockerClears = 0,
    Iterable<DiscoveryObjective> objectives = const [],
    Map<String, int> objectiveProgress = const {},
    Map<String, int> clearedByColor = const {},
    Iterable<DiscoveryTargetDrop> pendingDrops = const [],
    this.acceptedMoves = 0,
    this.iceCleared = 0,
  }) : requiredTargetIds = Set.unmodifiable(requiredTargetIds),
       collectedTargets = List.unmodifiable(collectedTargets),
       powerActivations = Map.unmodifiable(powerActivations),
       objectives = List.unmodifiable(objectives),
       objectiveProgress = Map.unmodifiable(objectiveProgress),
       clearedByColor = Map.unmodifiable(clearedByColor),
       pendingDrops = List.unmodifiable(pendingDrops);

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
  final Map<DiscoveryLinePower, int> powerActivations;
  final DiscoveryLinePower? requiredPowerKind;
  final int combinationActivations;
  final int requiredCombinationActivations;
  final int blockersCleared;
  final int requiredBlockerClears;
  final List<DiscoveryObjective> objectives;
  final Map<String, int> objectiveProgress;
  final Map<String, int> clearedByColor;
  final List<DiscoveryTargetDrop> pendingDrops;
  final int acceptedMoves;
  final int iceCleared;

  bool get isCompleted =>
      requiredTargetIds.every(collectedTargetIds.contains) &&
      linePowerActivations >= requiredLinePowerActivations &&
      (requiredPowerKind == null ||
          (powerActivations[requiredPowerKind] ?? 0) >= 1) &&
      combinationActivations >= requiredCombinationActivations &&
      blockersCleared >= requiredBlockerClears &&
      objectives.every(
        (goal) => (objectiveProgress[goal.id] ?? 0) >= goal.goal,
      );

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
