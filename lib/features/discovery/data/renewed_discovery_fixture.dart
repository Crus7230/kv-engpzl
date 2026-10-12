import '../../campaign/domain/board_mechanic_models.dart';
import '../../campaign/domain/campaign_models.dart';
import '../../puzzle/domain/equation_token.dart';
import '../domain/discovery_engine.dart';
import '../domain/discovery_hint_solver.dart';
import '../domain/discovery_models.dart';
import '../domain/discovery_piece_source.dart';
import 'discovery_excavation_profile.dart';

typedef _Instruction = ({
  DiscoveryPosition from,
  DiscoveryPosition to,
  String targetId,
});

/// v3 fixtures are self-checking at construction. This is not a substitute for
/// executing the regression suite or calibrating with family/device play.
class RenewedDiscoveryFixture {
  const RenewedDiscoveryFixture(
    this.board,
    this.referencePath, {
    this.objectives = const [],
    this.targetDrops = const [],
  });
  final DiscoveryBoard board;
  final List<_Instruction> referencePath;
  final List<DiscoveryObjective> objectives;
  final List<DiscoveryTargetDrop> targetDrops;

  static RenewedDiscoveryFixture create({
    required StageDefinition stage,
    required BoardLayoutVariant variant,
    required List<String> tokenIds,
    required Map<String, EquationToken> tokens,
    required List<String> gemKeys,
    DiscoveryExcavationProfile profile = const DiscoveryExcavationProfile(),
  }) {
    final rules = stage.boardMechanicPlan.bindings.map((b) => b.rule);
    final power = rules.whereType<LinePowerRule>().firstOrNull;
    final blocker = rules.whereType<AdjacentHitBlockerRule>().firstOrNull;
    final layers = rules.whereType<LayeredSealRule>().firstOrNull?.layers ?? 1;
    DiscoveryPiece targetFor(String id) {
      final token = tokens[id]!;
      return switch (token.kind) {
        EquationTokenKind.number => DiscoveryPiece.numberToken(
          id: id,
          label: token.label,
        ),
        EquationTokenKind.operator => DiscoveryPiece.operatorToken(
          id: id,
          label: token.label,
        ),
        _ => DiscoveryPiece.parenthesisToken(id: id, label: token.label),
      };
    }

    final remainingIds = List<String>.of(tokenIds);
    final reward = profile.colorGoals.isEmpty
        ? null
        : targetFor(remainingIds.removeLast());
    final drops = <DiscoveryTargetDrop>[
      if (profile.falling && remainingIds.length > (profile.ice ? 1 : 0))
        DiscoveryTargetDrop(
          target: targetFor(remainingIds.removeLast()),
          afterMoves: 2,
        ),
    ];
    final iceId = profile.ice && remainingIds.isNotEmpty
        ? remainingIds.removeAt(0)
        : null;
    final objectives = <DiscoveryObjective>[
      if (iceId != null)
        const DiscoveryObjective(
          id: 'ice',
          label: '얼음 깨기',
          kind: DiscoveryObjectiveKind.ice,
          goal: 1,
        ),
      for (final entry in profile.colorGoals.entries)
        DiscoveryObjective(
          id: 'color-${entry.key}',
          label: entry.key == 'B' ? '파란 보석' : '초록 보석',
          kind: DiscoveryObjectiveKind.color,
          goal: entry.value,
          matchKey: entry.key,
          rewardTarget: entry.key == profile.colorGoals.keys.first
              ? reward
              : null,
        ),
    ];
    final blockerPositions = [
      const DiscoveryPosition(1, 1),
      const DiscoveryPosition(3, 3),
      DiscoveryPosition(1, variant.config.columns - 2),
    ];
    DiscoveryEngine engine(DiscoveryBoard board) => DiscoveryEngine(
      initialBoard: board,
      requiredTargetIds: [
        ...board.buriedTargets.map((p) => p.id),
        ...drops.map((drop) => drop.target.id),
        if (reward != null) reward.id,
      ],
      moves: stage.moveLimit,
      enableLinePowers: power != null,
      enableBurstPowers: power?.enableBurst ?? false,
      enableColorPowers: power?.enableColor ?? false,
      enablePowerCombinations: power?.enableCombinations ?? false,
      requiredLinePowerActivations: power?.requiredActivations ?? 0,
      requiredPowerKind: switch (power?.lesson) {
        BoardPowerLesson.line => DiscoveryLinePower.row,
        BoardPowerLesson.burst => DiscoveryLinePower.burst,
        BoardPowerLesson.color => DiscoveryLinePower.color,
        _ => null,
      },
      requiredCombinationActivations:
          power?.lesson == BoardPowerLesson.combination ? 1 : 0,
      requiredBlockerClears: blocker?.blockerCount ?? 0,
      refillSource: SeededGemPieceSource(seed: variant.seed, gemKeys: gemKeys),
      objectives: objectives,
      targetDrops: drops,
    );
    for (var attempt = 0; attempt < 64; attempt++) {
      final random = _FixtureRandom(variant.seed ^ (attempt * 0x45d9f3b));
      final rows = <List<DiscoveryPiece>>[];
      for (var r = 0; r < variant.config.rows; r++) {
        final row = <DiscoveryPiece>[];
        for (var c = 0; c < variant.config.columns; c++) {
          String key;
          do {
            key = gemKeys[random.next(gemKeys.length)];
          } while (c >= 2 &&
                  row[c - 1].matchKey == key &&
                  row[c - 2].matchKey == key ||
              r >= 2 &&
                  rows[r - 1][c].matchKey == key &&
                  rows[r - 2][c].matchKey == key);
          row.add(
            DiscoveryPiece.gem(id: '${variant.fixtureId}-$r-$c', gemKey: key),
          );
        }
        rows.add(row);
      }
      void set(int r, int c, String key) {
        rows[r][c] = DiscoveryPiece.gem(
          id: '${variant.fixtureId}-$r-$c',
          gemKey: key,
        );
      }

      DiscoverySwapPair? opening;
      switch (power?.lesson) {
        case BoardPowerLesson.line:
        case BoardPowerLesson.color:
          final length = power!.lesson == BoardPowerLesson.color ? 5 : 4;
          for (var c = 0; c < length; c++) set(1, c, c == 2 ? 'B' : 'A');
          for (var c = length; c < variant.config.columns; c++) set(1, c, 'C');
          set(2, 2, 'A');
          opening = (
            from: const DiscoveryPosition(2, 2),
            to: const DiscoveryPosition(1, 2),
          );
        case BoardPowerLesson.burst:
          set(1, 1, 'A');
          set(1, 2, 'B');
          set(1, 3, 'A');
          set(0, 2, 'A');
          set(2, 2, 'A');
          set(3, 2, 'A');
          set(1, 0, 'C');
          set(1, 4, 'C');
          set(4, 2, 'C');
          opening = (
            from: const DiscoveryPosition(0, 2),
            to: const DiscoveryPosition(1, 2),
          );
        case BoardPowerLesson.combination:
          rows[1][1] = rows[1][1].withLinePower(DiscoveryLinePower.row);
          rows[1][2] = rows[1][2].withLinePower(DiscoveryLinePower.burst);
          opening = (
            from: const DiscoveryPosition(1, 1),
            to: const DiscoveryPosition(1, 2),
          );
        case null:
          if (stage.boardMechanicPlan.role == BoardMechanicRole.introduce &&
              blocker != null) {
            set(2, 0, 'A');
            set(2, 1, 'A');
            set(2, 2, 'B');
            set(3, 2, 'A');
            set(2, 3, 'C');
            opening = (
              from: const DiscoveryPosition(3, 2),
              to: const DiscoveryPosition(2, 2),
            );
          }
      }
      final covers = {
        for (final p in blockerPositions.take(blocker?.blockerCount ?? 0))
          p: blocker!.durability,
      };
      final icePosition = iceId == null
          ? null
          : DiscoveryPosition(2, variant.config.columns - 2);
      final ice = {if (icePosition != null) icePosition: 1};
      final searchTargets = {
        for (var r = 0; r < variant.config.rows; r++)
          for (var c = 0; c < variant.config.columns; c++)
            if (!covers.containsKey(DiscoveryPosition(r, c)))
              DiscoveryPosition(r, c): DiscoveryPiece.numberToken(
                id: 'search-$r-$c',
                label: '0',
              ),
      };
      final initial = DiscoveryBoard.fromRows(
        rows,
        config: variant.config,
        buriedTargets: searchTargets,
        sealLayers: {for (final p in searchTargets.keys) p: 1000},
        blockerLayers: covers,
        iceLayers: ice,
      );
      final path = <DiscoverySwapPair>[];
      final hitCounts = <DiscoveryPosition, int>{};
      final firstTurnHits = <DiscoveryPosition, int>{};
      final teachPartialLayer =
          layers == 2 &&
          remainingIds.isNotEmpty &&
          (stage.boardMechanicPlan.role == BoardMechanicRole.introduce ||
              stage.boardMechanicPlan.learningSourceStageId != null &&
                  power == null &&
                  blocker == null);
      DiscoveryEngine replay() {
        final branch = engine(initial);
        for (final move in path) {
          if (!branch.swap(move.from, move.to).isAccepted)
            throw StateError('Unstable fixture replay.');
        }
        return branch;
      }

      // Patching an instructional shape can introduce an unrelated starting
      // match. Reject that candidate; never settle it silently before play.
      try {
        engine(initial);
      } on ArgumentError {
        continue;
      }
      for (var step = 0; step < stage.moveBudget.referenceMoves; step++) {
        final current = replay();
        final moves = step == 0 && opening != null
            ? [opening]
            : DiscoveryBoardHintSolver.legalSwaps(current.state.board);
        DiscoverySwapPair? best;
        DiscoveryTurnResult? bestTurn;
        var bestScore = -1;
        for (final move in moves) {
          final branch = replay();
          final turn = branch.swap(move.from, move.to);
          if (!turn.isAccepted) continue;
          final counts = Map<DiscoveryPosition, int>.of(hitCounts);
          for (final cascade in turn.cascades) {
            for (final hit in cascade.sealHits)
              counts.update(hit.position, (n) => n + 1, ifAbsent: () => 1);
          }
          final focus = turn.state.requiredPowerKind;
          final focusCount = focus == null
              ? 0
              : turn.state.powerActivations[focus] ?? 0;
          final createdFocus = turn.cascades
              .expand((c) => c.createdPowers)
              .where((p) => focus == null || p.direction == focus)
              .length;
          final score =
              (focusCount > 0 ? 100000 : createdFocus * 10000) +
              turn.state.combinationActivations * 100000 +
              turn.state.blockersCleared * 20000 +
              counts.values.where((n) => n >= layers).length * 100 +
              counts.values.fold<int>(0, (a, b) => a + b) +
              turn.state.iceCleared * 200000 +
              turn.state.collectedTargetIds
                      .where((id) => tokenIds.contains(id))
                      .length *
                  300000 +
              turn.state.objectives.fold<int>(
                0,
                (total, objective) =>
                    total +
                    (turn.state.objectiveProgress[objective.id] ?? 0).clamp(
                          0,
                          objective.goal,
                        ) *
                        4000,
              );
          if (score > bestScore) {
            bestScore = score;
            best = move;
            bestTurn = turn;
          }
        }
        if (best == null || bestTurn == null) break;
        path.add(best);
        for (final cascade in bestTurn.cascades) {
          for (final hit in cascade.sealHits)
            hitCounts.update(hit.position, (n) => n + 1, ifAbsent: () => 1);
        }
        if (step == 0) firstTurnHits.addAll(hitCounts);
        final ready = hitCounts.entries
            .where(
              (e) =>
                  e.value >= layers &&
                  !covers.containsKey(e.key) &&
                  e.key != icePosition,
            )
            .map((e) => e.key)
            .toList();
        final state = bestTurn.state;
        final partialCandidates = ready
            .where((p) => firstTurnHits[p] == 1)
            .toList();
        if (teachPartialLayer && partialCandidates.isEmpty) continue;
        if (ready.length < remainingIds.length ||
            iceId != null && state.iceCleared == 0 ||
            drops.any(
              (drop) => !state.collectedTargetIds.contains(drop.target.id),
            ) ||
            state.objectives.any(
              (o) => (state.objectiveProgress[o.id] ?? 0) < o.goal,
            ) ||
            state.linePowerActivations < state.requiredLinePowerActivations ||
            state.requiredPowerKind != null &&
                (state.powerActivations[state.requiredPowerKind] ?? 0) < 1 ||
            state.combinationActivations <
                state.requiredCombinationActivations ||
            state.blockersCleared < state.requiredBlockerClears)
          continue;
        final targets = <DiscoveryPosition, DiscoveryPiece>{};
        for (final id in remainingIds) {
          final position = teachPartialLayer && targets.isEmpty
              ? partialCandidates[random.next(partialCandidates.length)]
              : ready[random.next(ready.length)];
          ready.remove(position);
          final token = tokens[id]!;
          targets[position] = switch (token.kind) {
            EquationTokenKind.number => DiscoveryPiece.numberToken(
              id: id,
              label: token.label,
            ),
            EquationTokenKind.operator => DiscoveryPiece.operatorToken(
              id: id,
              label: token.label,
            ),
            _ => DiscoveryPiece.parenthesisToken(id: id, label: token.label),
          };
        }
        if (icePosition != null) targets[icePosition] = targetFor(iceId!);
        final board = DiscoveryBoard.fromRows(
          rows,
          config: variant.config,
          buriedTargets: targets,
          sealLayers: {for (final p in targets.keys) p: layers},
          blockerLayers: covers,
          iceLayers: ice,
        );
        final actual = engine(board);
        final instructions = <_Instruction>[];
        for (final move in path) {
          if (actual.state.isCompleted) break;
          final turn = actual.swap(move.from, move.to);
          if (!turn.isAccepted)
            throw StateError('Fixture reference route became illegal.');
          instructions.add((
            from: move.from,
            to: move.to,
            targetId: turn.newlyDiscoveredTargets.firstOrNull?.id ?? '',
          ));
        }
        if (actual.state.isCompleted)
          return RenewedDiscoveryFixture(
            board,
            List.unmodifiable(instructions),
            objectives: List.unmodifiable(objectives),
            targetDrops: List.unmodifiable(drops),
          );
      }
    }
    throw StateError(
      'No renewed reference route within W/P/L: ${variant.fixtureId}.',
    );
  }
}

class _FixtureRandom {
  _FixtureRandom(int seed) : _state = seed & 0xffffffff;
  int _state;
  int next(int maximum) {
    _state = (1664525 * _state + 1013904223) % 0x100000000;
    return _state % maximum;
  }
}
