import '../../campaign/domain/campaign_models.dart';
import '../../campaign/domain/board_mechanic_models.dart';
import '../../puzzle/domain/equation_token.dart';
import '../../puzzle/domain/puzzle.dart';
import '../domain/discovery_engine.dart';
import '../domain/discovery_hint_solver.dart';
import '../domain/discovery_models.dart';
import '../domain/discovery_piece_source.dart';
import 'renewed_discovery_fixture.dart';
import 'discovery_excavation_profile.dart';

typedef DiscoverySwapInstruction = ({
  DiscoveryPosition from,
  DiscoveryPosition to,
  String targetId,
});

typedef _SearchMove = ({
  DiscoveryPosition from,
  DiscoveryPosition to,
  List<DiscoveryPosition> freshPositions,
});

/// Deterministic, freely playable boards for authored R1 content.
///
/// The reference path is found by enumerating legal swaps, not by restricting
/// player input. Core seals occupy first-clear cells; advanced fixtures verify
/// repeat hits and four-match creation/activation on the actual seeded engine.
/// This proves a route within W/P/L; it does not claim a minimum-move solution
/// or family-play calibration. Fixture IDs and seeds remain campaign-owned.
/// Reference steps with an empty targetId prepare a match or damage a layer;
/// a nonempty targetId is a verified token reveal, not a forced input rule.
class AuthoredDiscoveryFixture {
  AuthoredDiscoveryFixture._({
    required this.board,
    required this.referencePath,
    this.objectives = const [],
    this.targetDrops = const [],
  });

  static const gemKeys = ['A', 'B', 'C', 'D', 'E'];

  final DiscoveryBoard board;
  final List<DiscoverySwapInstruction> referencePath;
  final List<DiscoveryObjective> objectives;
  final List<DiscoveryTargetDrop> targetDrops;

  factory AuthoredDiscoveryFixture.create({
    required StageDefinition stage,
    required Puzzle puzzle,
    required BoardLayoutVariant variant,
  }) {
    final config = variant.config;
    final excavation = variant.fixtureId.endsWith('-excavation4');
    if (!(config.rows == config.columns &&
        (config.rows == 5 ||
            config.rows == 6 ||
            excavation && config.rows == 7))) {
      throw ArgumentError('Authored R1 fixtures support only 5x5 and 6x6.');
    }
    if (stage.puzzleId != puzzle.id ||
        stage.buriedTokenIds.isEmpty ||
        stage.buriedTokenIds.length > 3 ||
        stage.matchDifficulty.gemKindCount != gemKeys.length) {
      throw ArgumentError('Invalid authored token plan.');
    }
    final tokens = {for (final token in puzzle.tokens) token.id: token};
    final tokenIds = [
      for (final token in puzzle.tokens)
        if (stage.buriedTokenIds.contains(token.id)) token.id,
    ];
    if (tokenIds.length != stage.buriedTokenIds.length) {
      throw ArgumentError(
        'A buried target is missing from the puzzle manifest.',
      );
    }
    if (stage.startingTokenIds.intersection(stage.buriedTokenIds).isNotEmpty ||
        {...stage.startingTokenIds, ...stage.buriedTokenIds}.length !=
            puzzle.requiredTokenIds.length ||
        !puzzle.requiredTokenIds.containsAll({
          ...stage.startingTokenIds,
          ...stage.buriedTokenIds,
        })) {
      throw ArgumentError(
        'Starting and buried tokens must cover the manifest.',
      );
    }

    if (variant.fixtureId.endsWith('-physics3') || excavation) {
      final renewed = RenewedDiscoveryFixture.create(
        stage: stage,
        variant: variant,
        tokenIds: tokenIds,
        tokens: tokens,
        gemKeys: gemKeys,
        profile: excavation
            ? DiscoveryExcavationProfile.forStage(stage)
            : const DiscoveryExcavationProfile(),
      );
      return AuthoredDiscoveryFixture._(
        board: renewed.board,
        referencePath: renewed.referencePath,
        objectives: renewed.objectives,
        targetDrops: renewed.targetDrops,
      );
    }
    if (stage.boardMechanicPlan.advancedMechanicIds.isNotEmpty) {
      return _createAdvanced(stage, puzzle, variant, tokenIds, tokens);
    }

    for (var attempt = 0; attempt < 64; attempt += 1) {
      final initial = _generateBoard(variant, attempt);
      final path = _findPath(
        initial: initial,
        variant: variant,
        prefix: const [],
        length: tokenIds.length,
      );
      if (path == null) continue;
      final selector = _FixtureRandom(variant.seed ^ 0x6a09e667 ^ attempt);
      final targets = <DiscoveryPosition, DiscoveryPiece>{};
      for (var index = 0; index < path.length; index += 1) {
        final positions = path[index].freshPositions;
        final position = positions[selector.next(positions.length)];
        final token = tokens[tokenIds[index]]!;
        targets[position] = switch (token.kind) {
          EquationTokenKind.number => DiscoveryPiece.numberToken(
            id: token.id,
            label: token.label,
          ),
          EquationTokenKind.operator => DiscoveryPiece.operatorToken(
            id: token.id,
            label: token.label,
          ),
          _ => DiscoveryPiece.parenthesisToken(
            id: token.id,
            label: token.label,
          ),
        };
      }
      final board = DiscoveryBoard.fromRows(
        [
          for (final row in initial.cells)
            [for (final cell in row) cell.piece!],
        ],
        config: config,
        buriedTargets: targets,
      );
      final instructions = List<DiscoverySwapInstruction>.unmodifiable([
        for (var index = 0; index < path.length; index += 1)
          (
            from: path[index].from,
            to: path[index].to,
            targetId: tokenIds[index],
          ),
      ]);
      _verifyReferencePath(stage, variant, board, instructions);
      return AuthoredDiscoveryFixture._(
        board: board,
        referencePath: instructions,
      );
    }
    throw StateError('No verified board found for ${variant.fixtureId}.');
  }

  static AuthoredDiscoveryFixture _createAdvanced(
    StageDefinition stage,
    Puzzle puzzle,
    BoardLayoutVariant variant,
    List<String> tokenIds,
    Map<String, EquationToken> tokens,
  ) {
    final advanced = stage.boardMechanicPlan.advancedMechanicIds;
    if (advanced.any(
      (id) =>
          id != BoardMechanicId.layeredSeal && id != BoardMechanicId.linePower,
    )) {
      throw StateError('Unsupported board mechanic in ${stage.id}.');
    }
    final layers =
        stage.boardMechanicPlan.bindings
            .map((binding) => binding.rule)
            .whereType<LayeredSealRule>()
            .firstOrNull
            ?.layers ??
        1;
    final lineRule = stage.boardMechanicPlan.bindings
        .map((binding) => binding.rule)
        .whereType<LinePowerRule>()
        .firstOrNull;
    if (layers != 1 && layers != 2 ||
        lineRule != null &&
            (lineRule.creationMatchLength != 4 ||
                lineRule.requiredActivations != 1)) {
      throw StateError(
        'Only two-layer seals and one 4-match power are verified.',
      );
    }
    final enablePowers = lineRule != null;
    // Introductory fixtures expose the damaged seal between accepted moves,
    // instead of resolving both layers inside one automatic cascade.
    final requiresSeparatedIntroduction =
        layers == 2 && stage.chapterId == 'r01-c05' && stage.number <= 2;
    final maxSteps = stage.moveBudget.referenceMoves;
    for (var attempt = 0; attempt < 128; attempt++) {
      final initial = _generateBoard(variant, attempt);
      final prefix = <DiscoverySwapPair>[];
      final turns = <DiscoveryTurnResult>[];
      final hitCounts = <DiscoveryPosition, int>{};
      final firstTurnSingleHits = <DiscoveryPosition>{};
      DiscoveryEngine replay() {
        final targets = {
          for (final position in initial.positions)
            position: DiscoveryPiece.numberToken(
              id: 'search-${position.row}-${position.column}',
              label: '0',
            ),
        };
        final engine = DiscoveryEngine(
          initialBoard: DiscoveryBoard.fromRows(
            [
              for (final row in initial.cells)
                [for (final cell in row) cell.piece!],
            ],
            buriedTargets: targets,
            sealLayers: {
              for (final position in initial.positions) position: 100,
            },
          ),
          requiredTargetIds: targets.values.map((p) => p.id),
          moves: maxSteps,
          refillSource: SeededGemPieceSource(
            seed: variant.seed,
            gemKeys: gemKeys,
          ),
          enableLinePowers: enablePowers,
        );
        for (final swap in prefix) engine.swap(swap.from, swap.to);
        return engine;
      }

      var powersCreated = false;
      for (var step = 0; step < maxSteps; step++) {
        final current = replay();
        final legal = DiscoveryBoardHintSolver.legalSwaps(current.state.board);
        if (legal.isEmpty) break;
        DiscoverySwapPair? best;
        DiscoveryTurnResult? bestTurn;
        var bestScore = -1;
        final offset = _FixtureRandom(
          variant.seed ^ attempt ^ (step * 7919),
        ).next(legal.length);
        for (var index = 0; index < legal.length; index++) {
          final move = legal[(index + offset) % legal.length];
          final branch = replay();
          final turn = branch.swap(move.from, move.to);
          if (!turn.isAccepted) continue;
          final branchCounts = Map<DiscoveryPosition, int>.of(hitCounts);
          for (final cascade in turn.cascades) {
            for (final hit in cascade.sealHits) {
              branchCounts.update(
                hit.position,
                (count) => count + 1,
                ifAbsent: () => 1,
              );
            }
          }
          final ready = branchCounts.values
              .where((count) => count >= layers)
              .length;
          final hits = branchCounts.values.fold<int>(0, (a, b) => a + b);
          final created = turn.cascades.fold<int>(
            0,
            (n, c) => n + c.createdPowers.length,
          );
          final activations = turn.state.linePowerActivations;
          final score =
              (enablePowers && !powersCreated ? created * 10000 : 0) +
              (enablePowers && current.state.linePowerActivations == 0
                  ? activations * 5000
                  : 0) +
              ready * 100 +
              hits;
          if (score > bestScore) {
            bestScore = score;
            best = move;
            bestTurn = turn;
          }
        }
        if (best == null || bestTurn == null) break;
        prefix.add(best);
        turns.add(bestTurn);
        final thisTurnHits = <DiscoveryPosition, int>{};
        for (final cascade in bestTurn.cascades) {
          powersCreated = powersCreated || cascade.createdPowers.isNotEmpty;
          for (final hit in cascade.sealHits) {
            thisTurnHits.update(
              hit.position,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
            hitCounts.update(
              hit.position,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
          }
        }
        if (step == 0) {
          firstTurnSingleHits.addAll(
            thisTurnHits.entries
                .where((entry) => entry.value == 1)
                .map((entry) => entry.key),
          );
        }
        final eligible = hitCounts.entries
            .where((entry) => entry.value >= layers)
            .map((entry) => entry.key)
            .toList();
        if (eligible.length < tokenIds.length ||
            enablePowers &&
                (!powersCreated || bestTurn.state.linePowerActivations < 1))
          continue;
        final separatedTargets = eligible
            .where(firstTurnSingleHits.contains)
            .toList();
        if (requiresSeparatedIntroduction && separatedTargets.isEmpty) continue;
        final selector = _FixtureRandom(variant.seed ^ attempt ^ 0xbb67ae85);
        final targets = <DiscoveryPosition, DiscoveryPiece>{};
        for (final id in tokenIds) {
          final position = requiresSeparatedIntroduction && targets.isEmpty
              ? separatedTargets[selector.next(separatedTargets.length)]
              : eligible[selector.next(eligible.length)];
          eligible.remove(position);
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
        final board = DiscoveryBoard.fromRows(
          [
            for (final row in initial.cells)
              [for (final cell in row) cell.piece!],
          ],
          config: variant.config,
          buriedTargets: targets,
          sealLayers: {for (final position in targets.keys) position: layers},
        );
        final counts = <DiscoveryPosition, int>{};
        final instructions = <DiscoverySwapInstruction>[];
        for (var index = 0; index < prefix.length; index++) {
          var revealed = '';
          for (final cascade in turns[index].cascades) {
            for (final hit in cascade.sealHits) {
              final count = counts.update(
                hit.position,
                (n) => n + 1,
                ifAbsent: () => 1,
              );
              if (count == layers && targets.containsKey(hit.position)) {
                revealed = targets[hit.position]!.id;
              }
            }
          }
          instructions.add((
            from: prefix[index].from,
            to: prefix[index].to,
            targetId: revealed,
          ));
        }
        _verifyReferencePath(stage, variant, board, instructions);
        return AuthoredDiscoveryFixture._(
          board: board,
          referencePath: List.unmodifiable(instructions),
        );
      }
    }
    throw StateError('No advanced route found for ${variant.fixtureId}.');
  }

  static DiscoveryBoard _generateBoard(
    BoardLayoutVariant variant,
    int attempt,
  ) {
    final random = _FixtureRandom(
      variant.seed ^ 0x9e3779b9 ^ (attempt * 0x45d9f3b),
    );
    final rows = <List<DiscoveryPiece>>[];
    for (var row = 0; row < variant.config.rows; row += 1) {
      final pieces = <DiscoveryPiece>[];
      for (var column = 0; column < variant.config.columns; column += 1) {
        late String key;
        do {
          key = gemKeys[random.next(gemKeys.length)];
        } while ((column >= 2 &&
                pieces[column - 1].matchKey == key &&
                pieces[column - 2].matchKey == key) ||
            (row >= 2 &&
                rows[row - 1][column].matchKey == key &&
                rows[row - 2][column].matchKey == key));
        pieces.add(
          DiscoveryPiece.gem(
            id: '${variant.fixtureId}-initial-$row-$column',
            gemKey: key,
          ),
        );
      }
      rows.add(pieces);
    }
    return DiscoveryBoard.fromRows(rows, config: variant.config);
  }

  static List<_SearchMove>? _findPath({
    required DiscoveryBoard initial,
    required BoardLayoutVariant variant,
    required List<_SearchMove> prefix,
    required int length,
  }) {
    if (prefix.length == length) return prefix;
    final engine = _searchEngine(initial, variant, prefix);
    final moves = DiscoveryBoardHintSolver.legalSwaps(engine.state.board);
    if (moves.isEmpty) return null;
    final rotation = _FixtureRandom(
      variant.seed ^ (prefix.length * 0x27d4eb2d),
    ).next(moves.length);
    for (var index = 0; index < moves.length; index += 1) {
      final candidate = moves[(index + rotation) % moves.length];
      final branch = _searchEngine(initial, variant, prefix);
      final turn = branch.swap(candidate.from, candidate.to);
      if (!turn.isAccepted) continue;
      final freshPositions = [
        for (final cascade in turn.cascades)
          for (final target in cascade.discoveredTargets) target.position,
      ];
      if (freshPositions.isEmpty) continue;
      final result = _findPath(
        initial: initial,
        variant: variant,
        prefix: [
          ...prefix,
          (
            from: candidate.from,
            to: candidate.to,
            freshPositions: freshPositions,
          ),
        ],
        length: length,
      );
      if (result != null) return result;
    }
    return null;
  }

  static DiscoveryEngine _searchEngine(
    DiscoveryBoard initial,
    BoardLayoutVariant variant,
    List<_SearchMove> prefix,
  ) {
    // Temporary search-only targets track first clearance of every cell. They
    // never enter the playable board or the puzzle's token manifest.
    final searchTargets = {
      for (final position in initial.positions)
        position: DiscoveryPiece.numberToken(
          id: 'search-${position.row}-${position.column}',
          label: '0',
        ),
    };
    final engine = DiscoveryEngine(
      initialBoard: DiscoveryBoard.fromRows([
        for (final row in initial.cells) [for (final cell in row) cell.piece!],
      ], buriedTargets: searchTargets),
      requiredTargetIds: searchTargets.values.map((target) => target.id),
      moves: 3,
      refillSource: SeededGemPieceSource(seed: variant.seed, gemKeys: gemKeys),
    );
    for (final step in prefix) {
      if (!engine.swap(step.from, step.to).isAccepted) {
        throw StateError('An enumerated swap stopped being legal.');
      }
    }
    return engine;
  }

  static void _verifyReferencePath(
    StageDefinition stage,
    BoardLayoutVariant variant,
    DiscoveryBoard board,
    List<DiscoverySwapInstruction> instructions,
  ) {
    if (instructions.length > stage.moveBudget.referenceMoves ||
        instructions.length > stage.moveBudget.parMoves ||
        instructions.length > stage.moveLimit) {
      throw StateError('Reference route exceeds W/P/L for ${stage.id}.');
    }
    final engine = DiscoveryEngine(
      initialBoard: board,
      requiredTargetIds: stage.buriedTokenIds,
      moves: stage.moveLimit,
      refillSource: SeededGemPieceSource(seed: variant.seed, gemKeys: gemKeys),
      enableLinePowers: stage.boardMechanicPlan.mechanicIds.contains(
        BoardMechanicId.linePower,
      ),
      requiredLinePowerActivations:
          stage.boardMechanicPlan.bindings
              .map((binding) => binding.rule)
              .whereType<LinePowerRule>()
              .firstOrNull
              ?.requiredActivations ??
          0,
    );
    for (final step in instructions) {
      final turn = engine.swap(step.from, step.to);
      if (!turn.isAccepted ||
          (step.targetId.isNotEmpty &&
              !turn.newlyDiscoveredTargets.any((p) => p.id == step.targetId))) {
        throw StateError('Invalid reference route for ${variant.fixtureId}.');
      }
    }
    if (!engine.state.isCompleted) {
      throw StateError('Incomplete reference route for ${variant.fixtureId}.');
    }
  }
}

/// Explicit 32-bit arithmetic stays identical in Dart VM and JavaScript.
class _FixtureRandom {
  _FixtureRandom(int seed) : _state = seed & 0xffffffff;
  int _state;

  int next(int maximum) {
    _state = (1664525 * _state + 1013904223) % 0x100000000;
    return _state % maximum;
  }
}
