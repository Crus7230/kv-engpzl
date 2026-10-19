import '../../campaign/domain/board_mechanic_models.dart';
import '../../campaign/domain/campaign_models.dart';
import '../../puzzle/domain/equation_token.dart';
import '../domain/discovery_engine.dart';
import '../domain/discovery_hint_solver.dart';
import '../domain/discovery_models.dart';
import '../domain/discovery_piece_source.dart';
import 'discovery_challenge_profile.dart';
import 'renewed_discovery_fixture.dart';

class DiscoveryBoardGenerationException implements Exception {
  const DiscoveryBoardGenerationException(this.fixtureId);
  final String fixtureId;

  @override
  String toString() =>
      'No verified random board within the search budget: $fixtureId';
}

/// Generate the complete board BEFORE looking for a feasible route.
/// Search cannot change gems, fragments, covers, objectives or refill seeds.
/// A failed bounded search means "not verified", not proof of impossibility.
class RandomDiscoveryFixture {
  static RenewedDiscoveryFixture create({
    required StageDefinition stage,
    required BoardLayoutVariant variant,
    required List<String> tokenIds,
    required Map<String, EquationToken> tokens,
    required List<String> gemKeys,
  }) {
    if (DiscoveryChallengeProfile.isTutorial(stage)) {
      return RenewedDiscoveryFixture.create(
        stage: stage,
        variant: variant,
        tokenIds: tokenIds,
        tokens: tokens,
        gemKeys: gemKeys,
      );
    }
    final profile = DiscoveryChallengeProfile.forStage(stage);
    final enableSeeker = variant.fixtureId.endsWith('-random6');
    final rules = stage.boardMechanicPlan.bindings.map((b) => b.rule);
    final power = rules.whereType<LinePowerRule>().firstOrNull;
    final blocker = rules.whereType<AdjacentHitBlockerRule>().firstOrNull;
    final layers = rules.whereType<LayeredSealRule>().firstOrNull?.layers ?? 1;
    DiscoveryPiece tokenFor(String id) {
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

    // Keep earlier seal lessons. Only the existing C04+ delivery lessons use
    // delayed fragments; early play length comes from genuine gem objectives.
    final buried = List<String>.of(tokenIds);
    final drops = <DiscoveryTargetDrop>[
      if (profile.falling && buried.length > (profile.ice ? 1 : 0))
        DiscoveryTargetDrop(
          target: tokenFor(buried.removeLast()),
          afterMoves: 4,
        ),
    ];
    final objectives = <DiscoveryObjective>[
      if (profile.ice)
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
        ),
    ];

    DiscoveryEngine build(DiscoveryBoard board) => DiscoveryEngine(
      initialBoard: board,
      requiredTargetIds: tokenIds,
      moves: stage.moveLimit,
      enableLinePowers: power != null,
      enableSeekerPowers: enableSeeker,
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

    for (var candidate = 0; candidate < 96; candidate++) {
      final random = _BoardRandom(variant.seed ^ (candidate * 0x45d9f3b));
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
                  rows[r - 2][c].matchKey == key ||
              enableSeeker &&
                  r >= 1 &&
                  c >= 1 &&
                  row[c - 1].matchKey == key &&
                  rows[r - 1][c].matchKey == key &&
                  rows[r - 1][c - 1].matchKey == key);
          row.add(
            DiscoveryPiece.gem(
              id: '${variant.fixtureId}-$candidate-$r-$c',
              gemKey: key,
            ),
          );
        }
        rows.add(row);
      }
      final positions = [
        for (var r = 0; r < variant.config.rows; r++)
          for (var c = 0; c < variant.config.columns; c++)
            DiscoveryPosition(r, c),
      ];
      DiscoveryPosition take() =>
          positions.removeAt(random.next(positions.length));
      final covers = <DiscoveryPosition, int>{
        for (var n = 0; n < (blocker?.blockerCount ?? 0); n++)
          take(): blocker!.durability,
      };
      final targets = <DiscoveryPosition, DiscoveryPiece>{
        for (final id in buried) take(): tokenFor(id),
      };
      final ice = <DiscoveryPosition, int>{
        if (profile.ice) targets.keys.first: 1,
      };
      // Combination lessons supply two scattered tools, not a patched match
      // shape or a mandatory adjacent opening. Their meeting is player-owned.
      if (power?.lesson == BoardPowerLesson.combination) {
        for (final kind in [DiscoveryLinePower.row, DiscoveryLinePower.burst]) {
          final p = take();
          rows[p.row][p.column] = rows[p.row][p.column].withLinePower(kind);
        }
      }
      final board = DiscoveryBoard.fromRows(
        rows,
        config: variant.config,
        buriedTargets: targets,
        sealLayers: {for (final p in targets.keys) p: layers},
        blockerLayers: covers,
        iceLayers: ice,
      );
      final path = _verifyCandidate(
        board,
        build,
        stage.moveBudget.referenceMoves,
      );
      if (path != null) {
        return RenewedDiscoveryFixture(
          board,
          path,
          objectives: objectives,
          targetDrops: drops,
        );
      }
    }
    // Never fall back to planting tokens on a precomputed winning path.
    throw DiscoveryBoardGenerationException(variant.fixtureId);
  }

  static List<
    ({DiscoveryPosition from, DiscoveryPosition to, String targetId})
  >?
  _verifyCandidate(
    DiscoveryBoard board,
    DiscoveryEngine Function(DiscoveryBoard) build,
    int limit,
  ) {
    final path =
        <({DiscoveryPosition from, DiscoveryPosition to, String targetId})>[];
    DiscoveryEngine replay() {
      final engine = build(board);
      for (final move in path) engine.swap(move.from, move.to);
      return engine;
    }

    for (var step = 0; step < limit; step++) {
      final currentEngine = replay();
      final current = currentEngine.state;
      if (current.isCompleted) return List.unmodifiable(path);
      if (current.isDeadBoard || current.isOutOfMoves) return null;
      DiscoverySwapPair? best;
      DiscoveryTurnResult? bestTurn;
      var bestScore = double.negativeInfinity;
      for (final move in DiscoveryBoardHintSolver.legalSwaps(
        current.board,
        includeSquares: currentEngine.enableSeekerPowers,
      )) {
        final engine = replay();
        final turn = engine.swap(move.from, move.to);
        if (!turn.isAccepted) continue;
        final state = turn.state;
        final kind = current.requiredPowerKind;
        final needsKind =
            kind != null && (current.powerActivations[kind] ?? 0) == 0;
        final score =
            (state.isCompleted ? 1000000 : 0) +
            state.collectedTargetIds.length * 12000 +
            state.blockersCleared * 6000 +
            state.combinationActivations * 20000 +
            (needsKind ? (state.powerActivations[kind] ?? 0) * 20000 : 0) +
            (current.linePowerActivations < current.requiredLinePowerActivations
                ? state.linePowerActivations * 10000
                : 0) +
            turn.cascades
                    .expand((c) => c.createdPowers)
                    .where((p) => kind == null || p.direction == kind)
                    .length *
                (needsKind ? 15000 : 20) +
            state.objectives.fold<int>(
              0,
              (sum, goal) =>
                  sum +
                  (state.objectiveProgress[goal.id] ?? 0).clamp(0, goal.goal) *
                      150,
            ) +
            turn.cascades
                    .expand(
                      (c) => [...c.sealHits, ...c.iceHits, ...c.blockerHits],
                    )
                    .length *
                80 +
            turn.cascades.expand((c) => c.clearedPieces).length;
        if (score > bestScore) {
          bestScore = score.toDouble();
          best = move;
          bestTurn = turn;
        }
      }
      if (best == null || bestTurn == null) return null;
      path.add((
        from: best.from,
        to: best.to,
        targetId: bestTurn.newlyDiscoveredTargets.firstOrNull?.id ?? '',
      ));
      if (bestTurn.state.isCompleted) return List.unmodifiable(path);
    }
    return null;
  }
}

class _BoardRandom {
  _BoardRandom(int seed) : _state = seed & 0xffffffff;
  int _state;
  int next(int maximum) {
    _state = (1664525 * _state + 1013904223) % 0x100000000;
    return _state % maximum;
  }
}
