import 'dart:io';

import '../lib/features/campaign/data/initial_campaign.dart';
import '../lib/features/campaign/data/r1_authored_campaign.dart';
import '../lib/features/discovery/data/discovery_challenge_profile.dart';
import '../lib/features/discovery/data/discovery_excavation_profile.dart';
import '../lib/features/discovery/data/discovery_runtime_catalog.dart';
import '../lib/features/discovery/domain/discovery_engine.dart';
import '../lib/features/discovery/domain/discovery_models.dart';
import '../lib/features/discovery/domain/discovery_piece_source.dart';

void main(List<String> args) {
  _verifyBoardDensityPolicy();
  final smoke = args.contains('--smoke');
  final seedCount = args.contains('--seeds')
      ? int.parse(args[args.indexOf('--seeds') + 1])
      : 1;
  final ids = smoke
      ? [
          'r01-c01-s01',
          'r01-c01-s02',
          'r01-c01-s04',
          'r01-c02-s09',
          'r01-c02-s10',
          'r01-c04-s06',
          'r01-c05-s03',
          'r01-c06-s01',
          'r02-c01-s01',
          'r02-c06-s10',
        ]
      : authoredPuzzlesByStageId.keys;
  var count = 0;
  var earlyTotal = 0;
  var earlyCount = 0;
  var earlyMinimum = 99;
  var earlyMaximum = 0;
  var slowestMilliseconds = 0;
  var slowestBoard = '';
  final timer = Stopwatch()..start();
  for (final id in ids) {
    final original = initialCampaign.stageById(id)!;
    final stage = DiscoveryChallengeProfile.stageFor(original);
    final runtime = challengeDiscoveryRuntimeCatalog.resolve(stage);
    for (final config in [
      DiscoveryBoardConfig.compactPhone,
      DiscoveryBoardConfig.standardPhone,
      if (DiscoveryExcavationProfile.forStage(stage).dense)
        DiscoveryBoardConfig.densePhone,
    ]) {
      for (var sample = 0; sample < seedCount; sample++) {
        final variant = DiscoveryChallengeProfile.variantFor(
          stage,
          config,
          seed:
              (original.seed + sample * 2654435761 + config.rows * 97) &
              0xffffffff,
        );
        final generation = Stopwatch()..start();
        final board = runtime.buildBoard(variant);
        generation.stop();
        if (generation.elapsedMilliseconds > slowestMilliseconds) {
          slowestMilliseconds = generation.elapsedMilliseconds;
          slowestBoard = variant.fixtureId;
        }
        final objectives = runtime.objectivesFor!(variant);
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
          requiredCombinationActivations:
              runtime.requiredCombinationActivations,
          requiredBlockerClears: runtime.requiredBlockerClears,
          objectives: objectives,
          targetDrops: runtime.targetDropsFor!(variant),
          refillSource: SeededGemPieceSource(
            seed: variant.seed,
            gemKeys: runtime.gemKeys,
          ),
        );
        final engine = build();
        final restored = build();
        if (!DiscoveryChallengeProfile.isTutorial(stage)) {
          if (stage.matchDifficulty.hasScriptedOpening) {
            throw StateError('$id still claims a scripted opening.');
          }
          if (stage.moveLimit < 15 ||
              stage.moveLimit > 20 ||
              objectives.isEmpty)
            throw StateError('$id has no normal challenge.');
          if (engine.state.isCompleted || !engine.state.hasAvailableMove)
            throw StateError('$id has no playable start.');
        }
        final path = runtime.referencePathFor!(variant);
        if (path.length > stage.moveBudget.referenceMoves)
          throw StateError('$id exceeds W.');
        for (final move in path) {
          final turn = engine.swap(move.from, move.to);
          final replay = restored.swap(move.from, move.to);
          if (!turn.isAccepted || !replay.isAccepted)
            throw StateError('$id invalid witness.');
          if (engine.state.objectiveProgress.toString() !=
                  restored.state.objectiveProgress.toString() ||
              engine.state.board.visiblePieces
                      .map((p) => '${p.id}:${p.matchKey}')
                      .join(',') !=
                  restored.state.board.visiblePieces
                      .map((p) => '${p.id}:${p.matchKey}')
                      .join(',')) {
            throw StateError('$id deterministic replay mismatch.');
          }
          if (engine.state.isCompleted &&
              !engine.state.collectedTargetIds.containsAll(
                stage.buriedTokenIds,
              ))
            throw StateError('$id bypassed fragments.');
          if (engine.state.objectives.any(
                (o) => (engine.state.objectiveProgress[o.id] ?? 0) < o.goal,
              ) &&
              engine.state.isCompleted)
            throw StateError('$id bypassed goals.');
        }
        if (!engine.state.isCompleted)
          throw StateError('$id has no verified completion.');
        if (id.startsWith('r01-c01-') &&
            !DiscoveryChallengeProfile.isTutorial(stage)) {
          earlyCount++;
          earlyTotal += path.length;
          if (path.length < earlyMinimum) earlyMinimum = path.length;
          if (path.length > earlyMaximum) earlyMaximum = path.length;
        }
        count++;
        stdout.writeln(
          'PASS $id ${config.rows}x${config.columns} seed=${variant.seed} moves=${path.length}/${stage.moveLimit}',
        );
      }
    }
  }
  stdout.writeln(
    'Verified $count independently generated V5 boards and dual gates (${timer.elapsedMilliseconds}ms).',
  );
  if (earlyCount > 0)
    stdout.writeln(
      'R1 C01 non-tutorial witnesses: min=$earlyMinimum max=$earlyMaximum mean=${(earlyTotal / earlyCount).toStringAsFixed(2)}. Not a shortest-path or human-play claim.',
    );
  stdout.writeln(
    'Slowest desktop generation: ${slowestMilliseconds}ms $slowestBoard. Not Android profiling.',
  );
}

void _verifyBoardDensityPolicy() {
  final tutorial = initialCampaign.stageById('r01-c01-s01')!;
  final early = initialCampaign.stageById('r01-c01-s02')!;
  final advanced = initialCampaign.stageById('r02-c06-s10')!;
  final cases = [
    (stage: tutorial, width: 960.0, height: 432.0, side: 5),
    (stage: early, width: 800.0, height: 360.0, side: 6),
    (stage: early, width: 680.0, height: 300.0, side: 6),
    (stage: early, width: 480.0, height: 270.0, side: 5),
    (stage: advanced, width: 800.0, height: 360.0, side: 7),
    (stage: advanced, width: 720.0, height: 320.0, side: 7),
    (stage: advanced, width: 680.0, height: 300.0, side: 6),
    // SafeArea-reduced phone viewport: no strict 800x360 gate any more.
    (stage: advanced, width: 768.0, height: 344.0, side: 7),
  ];
  for (final sample in cases) {
    final config = DiscoveryChallengeProfile.boardFor(
      sample.stage,
      sample.width,
      sample.height,
    );
    if (config.rows != sample.side || config.columns != sample.side) {
      throw StateError('Unexpected density for ${sample.stage.id}: $sample');
    }
  }
  // Legacy selection remains immutable for callers replaying old rules.
  if (DiscoveryExcavationProfile.boardFor(early, 800, 360).rows != 5 ||
      DiscoveryExcavationProfile.boardFor(advanced, 720, 320).rows != 6) {
    throw StateError('The v4 board selection policy changed.');
  }
  stdout.writeln('PASS v5 5x5/6x6/7x7 density selection and legacy policy.');
}
