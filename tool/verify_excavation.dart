import 'dart:io';

import '../lib/features/campaign/data/initial_campaign.dart';
import '../lib/features/campaign/data/r1_authored_campaign.dart';
import '../lib/features/discovery/data/discovery_excavation_profile.dart';
import '../lib/features/discovery/data/discovery_runtime_catalog.dart';
import '../lib/features/discovery/domain/discovery_engine.dart';
import '../lib/features/discovery/domain/discovery_models.dart';
import '../lib/features/discovery/domain/discovery_piece_source.dart';

void main(List<String> args) {
  _verifyEngineContracts();
  final smoke = args.contains('--smoke');
  final ids = smoke
      ? <String>[
          'r01-c01-s01',
          'r01-c04-s02',
          'r01-c04-s04',
          'r01-c04-s08',
          'r01-c05-s03',
          'r01-c06-s01',
          'r02-c06-s10',
        ]
      : authoredPuzzlesByStageId.keys;
  var count = 0;
  for (final id in ids) {
    final stage = initialCampaign.stageById(id)!;
    final runtime = excavationDiscoveryRuntimeCatalog.resolve(stage);
    for (final config in [
      DiscoveryBoardConfig.compactPhone,
      DiscoveryBoardConfig.standardPhone,
      if (DiscoveryExcavationProfile.forStage(stage).dense)
        DiscoveryBoardConfig.densePhone,
    ]) {
      final variant = DiscoveryExcavationProfile.variantFor(stage, config);
      final board = runtime.buildBoard(variant);
      final objectives = runtime.objectivesFor!(variant);
      final drops = runtime.targetDropsFor!(variant);
      DiscoveryEngine build() => DiscoveryEngine(
        initialBoard: board,
        requiredTargetIds: stage.buriedTokenIds,
        moves: stage.moveLimit,
        enableLinePowers: runtime.enableLinePowers,
        requiredLinePowerActivations: runtime.requiredLinePowerActivations,
        enableBurstPowers: runtime.enableBurstPowers,
        enableColorPowers: runtime.enableColorPowers,
        enablePowerCombinations: runtime.enablePowerCombinations,
        requiredPowerKind: runtime.requiredPowerKind,
        requiredCombinationActivations: runtime.requiredCombinationActivations,
        requiredBlockerClears: runtime.requiredBlockerClears,
        objectives: objectives,
        targetDrops: drops,
        refillSource: SeededGemPieceSource(
          seed: variant.seed,
          gemKeys: runtime.gemKeys,
        ),
      );
      final engine = build();
      final replay = build();
      final path = runtime.referencePathFor!(variant);
      if (path.length > stage.moveBudget.referenceMoves)
        throw StateError('$id exceeds W.');
      for (final move in path) {
        final turn = engine.swap(move.from, move.to);
        final restored = replay.swap(move.from, move.to);
        if (!turn.isAccepted || !restored.isAccepted)
          throw StateError('$id illegal route.');
        if (turn.state.board.visiblePieces.toList().toString() !=
                restored.state.board.visiblePieces.toList().toString() ||
            turn.state.objectiveProgress.toString() !=
                restored.state.objectiveProgress.toString() ||
            turn.state.pendingDrops.length !=
                restored.state.pendingDrops.length) {
          throw StateError('$id replay mismatch.');
        }
        if (engine.state.acceptedMoves < 2 &&
            drops.any(
              (drop) => engine.state.board.visiblePieces.any(
                (piece) => piece.carriedTarget?.id == drop.target.id,
              ),
            )) {
          throw StateError('$id dropped a fragment prematurely.');
        }
      }
      if (!engine.state.isCompleted ||
          !engine.state.collectedTargetIds.containsAll(stage.buriedTokenIds)) {
        throw StateError('$id incomplete compound objectives.');
      }
      count++;
      stdout.writeln(
        'PASS $id ${config.rows}x${config.columns} ${path.length} moves',
      );
    }
  }
  stdout.writeln(
    'Verified $count v4 fixture routes, objectives and deterministic replay.',
  );
}

void _verifyEngineContracts() {
  void expect(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  DiscoveryBoard board({int ice = 0, bool carrier = false}) {
    const keys = ['A', 'B', 'C', 'D', 'E'];
    final rows = [
      for (var r = 0; r < 5; r++)
        [
          for (var c = 0; c < 5; c++)
            DiscoveryPiece.gem(id: 'contract-$r-$c', gemKey: keys[(r + c) % 5]),
        ],
    ];
    void set(int r, int c, String key) =>
        rows[r][c] = DiscoveryPiece.gem(id: 'contract-$r-$c', gemKey: key);
    set(2, 0, 'B');
    set(2, 1, 'B');
    set(2, 2, 'A');
    set(2, 3, 'D');
    set(2, 4, 'E');
    set(3, 2, 'B');
    if (carrier)
      rows[2][1] = rows[2][1].withCarriedTarget(
        const DiscoveryPiece.numberToken(id: 'carrier', label: '6'),
      );
    return DiscoveryBoard.fromRows(
      rows,
      buriedTargets: {
        if (ice > 0)
          const DiscoveryPosition(1, 1): const DiscoveryPiece.numberToken(
            id: 'ice',
            label: '7',
          ),
      },
      iceLayers: {if (ice > 0) const DiscoveryPosition(1, 1): ice},
    );
  }

  DiscoveryTurnResult play(DiscoveryEngine engine) =>
      engine.swap(const DiscoveryPosition(3, 2), const DiscoveryPosition(2, 2));
  final colors = DiscoveryEngine(
    initialBoard: board(),
    requiredTargetIds: const {'reward'},
    moves: 12,
    refillSource: SeededGemPieceSource(seed: 7),
    objectives: const [
      DiscoveryObjective(
        id: 'blue',
        label: '파란 보석',
        kind: DiscoveryObjectiveKind.color,
        matchKey: 'B',
        goal: 3,
        rewardTarget: DiscoveryPiece.numberToken(id: 'reward', label: '5'),
      ),
      DiscoveryObjective(
        id: 'green',
        label: '초록 보석',
        kind: DiscoveryObjectiveKind.color,
        matchKey: 'E',
        goal: 999,
      ),
    ],
  );
  final colorTurn = play(colors);
  expect(
    colorTurn.isAccepted && colors.state.collectedTargetIds.contains('reward'),
    'Color reward must be earned.',
  );
  expect(
    !colors.state.isCompleted,
    'One completed goal cannot satisfy compound AND.',
  );
  expect(
    colorTurn.newlyDiscoveredTargets.where((p) => p.id == 'reward').length == 1,
    'A color reward must be unique.',
  );
  expect(
    colorTurn.state.clearedByColor['B'] ==
        colorTurn.cascades
            .expand((c) => c.clearedPieces)
            .where((p) => p.piece.matchKey == 'B')
            .length,
    'Count only actually removed blue pieces.',
  );
  final ice = DiscoveryEngine(
    initialBoard: board(ice: 2),
    requiredTargetIds: const {'ice'},
    moves: 12,
    refillSource: SeededGemPieceSource(seed: 7),
  );
  expect(
    ice
            .swap(const DiscoveryPosition(1, 1), const DiscoveryPosition(1, 2))
            .status ==
        DiscoverySwapStatus.blocked,
    'Ice cannot be swapped.',
  );
  final iceTurn = play(ice);
  expect(
    iceTurn.cascades.first.iceHits.single.layersAfter == 1 &&
        iceTurn.cascades.first.discoveredTargets.isEmpty,
    'Overlapping adjacent hits cannot break two ice layers in one cascade.',
  );
  final pending = DiscoveryEngine(
    initialBoard: board(),
    requiredTargetIds: const {'drop'},
    moves: 12,
    refillSource: SeededGemPieceSource(seed: 7),
    targetDrops: const [
      DiscoveryTargetDrop(
        target: DiscoveryPiece.operatorToken(id: 'drop', label: '+'),
        afterMoves: 2,
      ),
    ],
  );
  pending.swap(const DiscoveryPosition(0, 0), const DiscoveryPosition(0, 0));
  expect(
    pending.state.acceptedMoves == 0,
    'Invalid input cannot advance a drop.',
  );
  play(pending);
  expect(
    pending.state.pendingDrops.length == 1 &&
        pending.state.collectedTargetIds.isEmpty,
    'A fragment must not drop or be awarded before its move gate.',
  );
  final carrier = DiscoveryEngine(
    initialBoard: board(carrier: true),
    requiredTargetIds: const {'carrier'},
    moves: 12,
    refillSource: SeededGemPieceSource(seed: 7),
  );
  expect(
    carrier.state.collectedTargetIds.isEmpty,
    'A visible carrier is not an earned fragment.',
  );
  play(carrier);
  expect(
    carrier.state.isCompleted &&
        carrier.state.collectedTargetIds.contains('carrier'),
    'Clearing a carrier must collect its unique fragment.',
  );
  stdout.writeln(
    'PASS engine contracts: compound AND, color counts, unique reward, ice, delayed drop, carrier collection.',
  );
}
