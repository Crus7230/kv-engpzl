import '../../campaign/data/initial_campaign.dart';
import '../../campaign/data/r1_authored_campaign.dart';
import '../../campaign/domain/campaign_models.dart';
import '../../campaign/domain/board_mechanic_models.dart';
import '../../puzzle/data/sample_puzzles.dart';
import '../../puzzle/domain/equation_token.dart';
import '../../puzzle/domain/puzzle.dart';
import '../domain/discovery_engine.dart';
import '../domain/discovery_hint_solver.dart';
import '../domain/discovery_models.dart';
import '../domain/discovery_piece_source.dart';
import 'authored_discovery_fixture.dart';
import 'tutorial_discovery_fixture.dart';

typedef DiscoveryTutorialStep = DiscoverySwapInstruction;

/// Runtime content is registered separately from the planned curriculum.
/// A new stage needs its own authored puzzle and verified board builder.
class DiscoveryStageRuntime {
  DiscoveryStageRuntime({
    required this.puzzle,
    required this.buildBoard,
    required this.refillPieces,
    required this.gemKeys,
    this.tutorialSteps = const [],
    this.referencePathFor,
    this.suggestSwapFor,
    this.enableLinePowers = false,
    this.requiredLinePowerActivations = 0,
  });

  final Puzzle puzzle;
  final DiscoveryBoard Function(BoardLayoutVariant variant) buildBoard;
  final List<DiscoveryPiece> Function(BoardLayoutVariant variant) refillPieces;
  final List<String> gemKeys;
  final List<DiscoveryTutorialStep> tutorialSteps;
  final bool enableLinePowers;
  final int requiredLinePowerActivations;

  /// Verification/manual-play route. Unlike [tutorialSteps], this never
  /// restricts swaps or supplies an unsolicited direct-path hint.
  final List<DiscoverySwapInstruction> Function(BoardLayoutVariant variant)?
  referencePathFor;
  final DiscoveryHintSuggestion? Function(
    BoardLayoutVariant variant,
    List<List<int>> acceptedSwaps,
  )?
  suggestSwapFor;
}

class DiscoveryRuntimeCatalog {
  DiscoveryRuntimeCatalog(Map<String, DiscoveryStageRuntime> entries)
    : _entries = Map.unmodifiable(entries);

  final Map<String, DiscoveryStageRuntime> _entries;

  DiscoveryStageRuntime resolve(StageDefinition stage) {
    if (!stage.isPlayable || !_entries.containsKey(stage.id)) {
      throw StateError('Stage ${stage.id} has no playable runtime content.');
    }
    return _entries[stage.id]!;
  }

  bool contains(String stageId) => _entries.containsKey(stageId);
}

final discoveryRuntimeCatalog = DiscoveryRuntimeCatalog({
  verticalSliceStage.id: DiscoveryStageRuntime(
    puzzle: samplePuzzles.firstWhere(
      (p) => p.id == verticalSliceStage.puzzleId,
    ),
    gemKeys: const ['A', 'B', 'C', 'D', 'E'],
    tutorialSteps: DiscoveryTutorialFixture.steps,
    referencePathFor: (_) => DiscoveryTutorialFixture.steps,
    buildBoard: (variant) => DiscoveryTutorialFixture.build(
      config: variant.config,
      timesTarget: _tokenPiece('p1-times'),
      plusTarget: _tokenPiece('p1-plus'),
      twoTarget: _tokenPiece('p1-n2'),
    ),
    refillPieces: (variant) =>
        DiscoveryTutorialFixture.refillPieces(idPrefix: variant.fixtureId),
  ),
  for (final stage in initialCampaign.stages)
    if (r1PuzzlesByStageId.containsKey(stage.id))
      stage.id: _authoredRuntime(stage, r1PuzzlesByStageId[stage.id]!),
});

DiscoveryStageRuntime _authoredRuntime(StageDefinition stage, Puzzle puzzle) {
  final fixtures = <String, AuthoredDiscoveryFixture>{};
  AuthoredDiscoveryFixture fixture(BoardLayoutVariant variant) =>
      fixtures.putIfAbsent(
        variant.fixtureId,
        () => AuthoredDiscoveryFixture.create(
          stage: stage,
          puzzle: puzzle,
          variant: variant,
        ),
      );
  return DiscoveryStageRuntime(
    puzzle: puzzle,
    gemKeys: AuthoredDiscoveryFixture.gemKeys,
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
    buildBoard: (variant) => fixture(variant).board,
    refillPieces: (_) => const [],
    referencePathFor: (variant) => fixture(variant).referencePath,
    suggestSwapFor: (variant, acceptedSwaps) =>
        const DiscoveryBoardHintSolver().suggest(
          replay: (additionalSwaps) {
            final engine = DiscoveryEngine(
              initialBoard: fixture(variant).board,
              requiredTargetIds: stage.buriedTokenIds,
              moves: stage.moveLimit,
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
              refillSource: SeededGemPieceSource(
                seed: variant.seed,
                idPrefix: '${stage.id}-${variant.fixtureId}-refill',
                gemKeys: AuthoredDiscoveryFixture.gemKeys,
              ),
            );
            for (final swap in acceptedSwaps) {
              final columns = variant.config.columns;
              final turn = engine.swap(
                DiscoveryPosition(swap[0] ~/ columns, swap[0] % columns),
                DiscoveryPosition(swap[1] ~/ columns, swap[1] % columns),
              );
              if (!turn.isAccepted) {
                throw StateError(
                  'The current hint session cannot be replayed.',
                );
              }
            }
            for (final swap in additionalSwaps) {
              if (!engine.swap(swap.from, swap.to).isAccepted) {
                throw StateError('A proposed hint branch cannot be replayed.');
              }
            }
            return engine;
          },
        ),
  );
}

DiscoveryPiece _tokenPiece(String id) {
  final token = samplePuzzles.first.tokens.firstWhere(
    (token) => token.id == id,
  );
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
