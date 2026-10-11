import 'dart:io';

import '../lib/features/campaign/data/initial_campaign.dart';
import '../lib/features/campaign/domain/board_mechanic_models.dart';
import '../lib/features/discovery/data/discovery_runtime_catalog.dart';
import '../lib/features/discovery/domain/discovery_engine.dart';
import '../lib/features/discovery/domain/discovery_piece_source.dart';

void main() {
  var layeredFixtures = 0;
  var lineFixtures = 0;
  var mixedFixtures = 0;
  var longest = 0;
  for (final stage in initialCampaign.stages.where(
    (s) =>
        s.id.startsWith('r01-') &&
        s.isPlayable &&
        s.boardMechanicPlan.advancedMechanicIds.isNotEmpty,
  )) {
    final mechanics = stage.boardMechanicPlan.mechanicIds;
    final layered = mechanics.contains(BoardMechanicId.layeredSeal);
    final powered = mechanics.contains(BoardMechanicId.linePower);
    _expect(
      currentDiscoveryBoardMechanics.supportsForPlay(stage.boardMechanicPlan),
      '${stage.id} only uses verified mechanics.',
    );
    final runtime = discoveryRuntimeCatalog.resolve(stage);
    for (final variant in stage.boardVariants.variants) {
      final board = runtime.buildBoard(variant);
      _expect(
        board.cells
            .expand((row) => row)
            .where((c) => c.buriedTarget != null)
            .every((c) => c.sealLayers == (layered ? 2 : 1)),
        '${stage.id} layers agree with the runtime plan.',
      );
      final engine = DiscoveryEngine(
        initialBoard: board,
        requiredTargetIds: stage.buriedTokenIds,
        moves: stage.moveLimit,
        enableLinePowers: runtime.enableLinePowers,
        requiredLinePowerActivations: runtime.requiredLinePowerActivations,
        refillSource: SeededGemPieceSource(
          seed: variant.seed,
          gemKeys: runtime.gemKeys,
        ),
      );
      var created = 0;
      final route = runtime.referencePathFor!(variant);
      if (route.length > longest) longest = route.length;
      for (final swap in route) {
        final turn = engine.swap(swap.from, swap.to);
        _expect(turn.isAccepted, '${variant.fixtureId} legal path.');
        for (final cascade in turn.cascades) {
          created += cascade.createdPowers.length;
          _expect(
            cascade.sealHits.map((h) => h.position).toSet().length ==
                cascade.sealHits.length,
            'One hit per cell per cascade.',
          );
          _expect(
            cascade.sealHits.every((h) => h.layersBefore - h.layersAfter == 1),
            'Every hit removes exactly one layer.',
          );
        }
      }
      _expect(engine.state.isCompleted, '${variant.fixtureId} complete.');
      if (powered) {
        _expect(
          created > 0 && engine.state.linePowerActivations >= 1,
          '${variant.fixtureId} creates and activates a power in actual play.',
        );
        lineFixtures++;
      }
      if (layered) layeredFixtures++;
      if (layered && powered) mixedFixtures++;
    }
  }
  _expect(
    layeredFixtures == 30 && lineFixtures == 30 && mixedFixtures == 20,
    'All advanced R1 stage pairs are present.',
  );
  stdout.writeln(
    'Discovery effects: $layeredFixtures layered, '
    '$lineFixtures line-power, $mixedFixtures mixed fixtures; '
    'longest reference path $longest moves. Human calibration pending.',
  );
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
