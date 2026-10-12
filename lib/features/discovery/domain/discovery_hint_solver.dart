import 'discovery_engine.dart';
import 'discovery_models.dart';

typedef DiscoverySwapPair = ({DiscoveryPosition from, DiscoveryPosition to});

class DiscoveryHintSuggestion {
  const DiscoveryHintSuggestion({
    required this.from,
    required this.to,
    this.targetId,
    this.movesToTarget,
    this.route = const [],
    this.activatesLinePower = false,
    this.createsLinePower = false,
  });

  final DiscoveryPosition from;
  final DiscoveryPosition to;

  /// Null means this is only a legal match, not a proven route to a seal.
  final String? targetId;
  final int? movesToTarget;
  final List<DiscoverySwapPair> route;
  final bool activatesLinePower;
  final bool createsLinePower;
}

/// Bounded search over the current board and its exact seeded refill stream.
///
/// [replay] must reconstruct the live session plus the supplied extra swaps.
/// No move is applied to the live engine by asking for a hint.
class DiscoveryBoardHintSolver {
  const DiscoveryBoardHintSolver({
    this.searchDepth = 3,
    this.maxEvaluatedSwaps = 128,
  }) : assert(searchDepth > 0),
       assert(maxEvaluatedSwaps > 0);

  final int searchDepth;
  final int maxEvaluatedSwaps;

  DiscoveryHintSuggestion? suggest({
    required DiscoveryEngine Function(List<DiscoverySwapPair> extraSwaps)
    replay,
  }) {
    final state = replay(const []).state;
    if (state.isCompleted || state.isOutOfMoves || state.isDeadBoard)
      return null;
    final firstMoves = legalSwaps(state.board);
    if (firstMoves.isEmpty) return null;
    final fallback = DiscoveryHintSuggestion(
      from: firstMoves.first.from,
      to: firstMoves.first.to,
      route: List.unmodifiable([firstMoves.first]),
    );
    var evaluated = 0;
    var frontier = <List<DiscoverySwapPair>>[const []];
    for (
      var depth = 1;
      depth <= searchDepth && depth <= state.movesRemaining;
      depth += 1
    ) {
      final next = <List<DiscoverySwapPair>>[];
      for (final prefix in frontier) {
        final board = prefix.isEmpty ? state.board : replay(prefix).state.board;
        for (final move in legalSwaps(board)) {
          if (evaluated >= maxEvaluatedSwaps) return fallback;
          evaluated += 1;
          final branch = replay(prefix);
          final turn = branch.swap(move.from, move.to);
          if (!turn.isAccepted) continue;
          final path = [...prefix, move];
          final targets = turn.newlyDiscoveredTargets.where(
            (target) => turn.state.requiredTargetIds.contains(target.id),
          );
          if (state.objectives.any(
            (goal) =>
                (state.objectiveProgress[goal.id] ?? 0) < goal.goal &&
                (turn.state.objectiveProgress[goal.id] ?? 0) >
                    (state.objectiveProgress[goal.id] ?? 0),
          )) {
            return DiscoveryHintSuggestion(
              from: path.first.from,
              to: path.first.to,
              route: List.unmodifiable(path),
            );
          }
          final needsPower =
              state.linePowerActivations < state.requiredLinePowerActivations ||
              (state.requiredPowerKind != null &&
                  (state.powerActivations[state.requiredPowerKind] ?? 0) ==
                      0) ||
              state.combinationActivations <
                  state.requiredCombinationActivations;
          final activates =
              turn.state.linePowerActivations > state.linePowerActivations;
          final creates = turn.cascades.any((c) => c.createdPowers.isNotEmpty);
          final requiredKind = state.requiredPowerKind;
          final relevantPower =
              requiredKind == null ||
              (turn.state.powerActivations[requiredKind] ?? 0) >
                  (state.powerActivations[requiredKind] ?? 0) ||
              turn.cascades.any(
                (c) => c.createdPowers.any((p) => p.direction == requiredKind),
              );
          final needsCombination =
              state.combinationActivations <
              state.requiredCombinationActivations;
          if (needsPower &&
              (activates || creates) &&
              relevantPower &&
              (!needsCombination ||
                  turn.state.combinationActivations >
                      state.combinationActivations)) {
            return DiscoveryHintSuggestion(
              from: path.first.from,
              to: path.first.to,
              route: List.unmodifiable(path),
              activatesLinePower: activates,
              createsLinePower: !activates,
            );
          }
          if (state.blockersCleared < state.requiredBlockerClears &&
              turn.state.blockersCleared > state.blockersCleared) {
            return DiscoveryHintSuggestion(
              from: path.first.from,
              to: path.first.to,
              route: List.unmodifiable(path),
            );
          }
          if (targets.isNotEmpty) {
            return DiscoveryHintSuggestion(
              from: path.first.from,
              to: path.first.to,
              targetId: targets.first.id,
              movesToTarget: path.length,
              route: List.unmodifiable(path),
            );
          }
          if (!turn.state.isDeadBoard && !turn.state.isOutOfMoves)
            next.add(path);
        }
      }
      if (next.isEmpty) break;
      frontier = next;
    }
    return fallback;
  }

  /// The engine always settles cascades, so a new match must involve one of
  /// the two swapped positions. Returned pairs are adjacent and in bounds.
  static List<DiscoverySwapPair> legalSwaps(DiscoveryBoard board) {
    final keys = <List<String?>>[
      for (var row = 0; row < board.rowCount; row++)
        [
          for (var column = 0; column < board.columnCount; column++)
            board.matchKeyAt(DiscoveryPosition(row, column)),
        ],
    ];
    final moves = <DiscoverySwapPair>[];
    for (final from in board.positions) {
      for (final to in [
        DiscoveryPosition(from.row, from.column + 1),
        DiscoveryPosition(from.row + 1, from.column),
      ]) {
        if (!board.canSwapAt(from) || !board.canSwapAt(to)) continue;
        final first = keys[from.row][from.column];
        keys[from.row][from.column] = keys[to.row][to.column];
        keys[to.row][to.column] = first;
        if (board.pieceAt(from)?.linePower != null ||
            board.pieceAt(to)?.linePower != null ||
            _hasMatchAt(keys, from) ||
            _hasMatchAt(keys, to)) {
          moves.add((from: from, to: to));
        }
        keys[to.row][to.column] = keys[from.row][from.column];
        keys[from.row][from.column] = first;
      }
    }
    return moves;
  }

  static bool _hasMatchAt(
    List<List<String?>> keys,
    DiscoveryPosition position,
  ) {
    final key = keys[position.row][position.column];
    if (key == null) return false;
    var horizontal = 1;
    for (
      var column = position.column - 1;
      column >= 0 && keys[position.row][column] == key;
      column -= 1
    ) {
      horizontal += 1;
    }
    for (
      var column = position.column + 1;
      column < keys.first.length && keys[position.row][column] == key;
      column += 1
    ) {
      horizontal += 1;
    }
    if (horizontal >= 3) return true;
    var vertical = 1;
    for (
      var row = position.row - 1;
      row >= 0 && keys[row][position.column] == key;
      row -= 1
    ) {
      vertical += 1;
    }
    for (
      var row = position.row + 1;
      row < keys.length && keys[row][position.column] == key;
      row += 1
    ) {
      vertical += 1;
    }
    return vertical >= 3;
  }
}
