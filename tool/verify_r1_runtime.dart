import 'dart:io';

import '../lib/features/campaign/data/initial_campaign.dart';
import '../lib/features/campaign/data/r1_authored_campaign.dart';
import '../lib/features/discovery/data/discovery_runtime_catalog.dart';
import '../lib/features/discovery/domain/discovery_engine.dart';
import '../lib/features/discovery/domain/discovery_piece_source.dart';
import '../lib/features/puzzle/domain/equation_token.dart';
import '../lib/features/puzzle/domain/puzzle.dart';

void main() {
  _expect(r1PuzzlesByStageId.length == 60, 'Exactly 60 authored R1 puzzles.');
  var fixtureCount = 0;
  var referenceMoves = 0;
  final timer = Stopwatch()..start();
  for (final id in r1PuzzlesByStageId.keys) {
    final stage = initialCampaign.stageById(id)!;
    _expect(stage.isPlayable, '$id is authored and playable.');
    final runtime = discoveryRuntimeCatalog.resolve(stage);
    final remaining = [...runtime.puzzle.tokens];
    final expression = <EquationToken>[
      for (final match in RegExp(
        r'\d+|[+\-×÷()]',
      ).allMatches(stage.answerExpression))
        remaining.removeAt(
          remaining.indexWhere((token) => token.label == match.group(0)),
        ),
    ];
    _expect(
      const PuzzleValidator().validate(runtime.puzzle, expression).isCorrect,
      '$id expression matches both target and intended AST.',
    );
    for (final variant in stage.boardVariants.variants) {
      _expect(variant.isVerified, '${variant.fixtureId} is verified.');
      final board = runtime.buildBoard(variant);
      final path = runtime.referencePathFor!(variant);
      _expect(path.length <= stage.moveBudget.referenceMoves, '$id meets W.');
      _expect(path.length <= stage.moveBudget.parMoves, '$id meets P.');
      _expect(path.length <= stage.moveLimit, '$id meets L.');
      final engine = DiscoveryEngine(
        initialBoard: board,
        requiredTargetIds: stage.buriedTokenIds,
        moves: stage.moveLimit,
        enableLinePowers: runtime.enableLinePowers,
        requiredLinePowerActivations: runtime.requiredLinePowerActivations,
        refillSource: QueuedPieceSource(
          pieces: runtime.refillPieces(variant),
          fallback: SeededGemPieceSource(
            seed: variant.seed,
            gemKeys: runtime.gemKeys,
          ),
        ),
      );
      _expect(
        engine.state.hasAvailableMove,
        '${variant.fixtureId} starts playable.',
      );
      for (final step in path) {
        final turn = engine.swap(step.from, step.to);
        _expect(turn.isAccepted, '${variant.fixtureId} swap is legal.');
        if (step.targetId.isNotEmpty) {
          _expect(
            turn.newlyDiscoveredTargets.any(
              (piece) => piece.id == step.targetId,
            ),
            '${variant.fixtureId} claimed token reveal is verified.',
          );
        }
      }
      _expect(
        engine.state.isCompleted,
        '${variant.fixtureId} discovers all tokens.',
      );
      fixtureCount += 1;
      referenceMoves += path.length;
    }
  }
  timer.stop();
  _expect(fixtureCount == 120, 'Every puzzle has both 5x5 and 6x6 fixtures.');
  stdout.writeln(
    'R1 runtime: 60 puzzles, $fixtureCount verified fixtures, '
    '$referenceMoves legal reference swaps (${timer.elapsedMilliseconds} ms). '
    'Human play calibration remains pending.',
  );
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
