import '../../campaign/data/initial_campaign.dart';
import '../../campaign/data/r1_authored_campaign.dart';
import '../../campaign/domain/campaign_models.dart';
import '../../campaign/domain/board_mechanic_models.dart';
import '../../campaign/domain/sentence_math_validator.dart';
import '../../puzzle/data/sample_puzzles.dart';
import '../../puzzle/domain/equation_token.dart';
import '../../puzzle/domain/puzzle.dart';
import '../domain/discovery_engine.dart';
import '../domain/discovery_hint_solver.dart';
import '../domain/discovery_models.dart';
import '../domain/discovery_piece_source.dart';
import 'authored_discovery_fixture.dart';
import 'tutorial_discovery_fixture.dart';
import 'discovery_challenge_profile.dart';

typedef DiscoveryTutorialStep = DiscoverySwapInstruction;

/// Runtime content is registered separately from the planned curriculum.
/// A new stage needs its own authored puzzle and self-checking board builder.
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
    this.enableBurstPowers = false,
    this.enableColorPowers = false,
    this.enablePowerCombinations = false,
    this.requiredPowerKind,
    this.requiredCombinationActivations = 0,
    this.requiredBlockerClears = 0,
    this.objectivesFor,
    this.targetDropsFor,
  });

  final Puzzle puzzle;
  final DiscoveryBoard Function(BoardLayoutVariant variant) buildBoard;
  final List<DiscoveryPiece> Function(BoardLayoutVariant variant) refillPieces;
  final List<String> gemKeys;
  final List<DiscoveryTutorialStep> tutorialSteps;
  final bool enableLinePowers;
  final int requiredLinePowerActivations;
  final bool enableBurstPowers;
  final bool enableColorPowers;
  final bool enablePowerCombinations;
  final DiscoveryLinePower? requiredPowerKind;
  final int requiredCombinationActivations;
  final int requiredBlockerClears;
  final List<DiscoveryObjective> Function(BoardLayoutVariant variant)?
  objectivesFor;
  final List<DiscoveryTargetDrop> Function(BoardLayoutVariant variant)?
  targetDropsFor;

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
    final runtime = _entries[stage.id]!;
    final issues = const SentenceMathValidator().validate(
      stage,
      runtime.puzzle,
    );
    if (issues.isNotEmpty) {
      throw StateError(
        'Stage ${stage.id} has invalid sentence content: '
        '${issues.map((issue) => issue.name).join(', ')}.',
      );
    }
    return runtime;
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
    if (authoredPuzzlesByStageId.containsKey(stage.id))
      stage.id: _authoredRuntime(stage, authoredPuzzlesByStageId[stage.id]!),
});

/// V4 delivery data is selected by its excavation fixture variant; v3 stays
/// registered separately for exact saved-board replay.
final excavationDiscoveryRuntimeCatalog = DiscoveryRuntimeCatalog({
  verticalSliceStage.id: discoveryRuntimeCatalog.resolve(verticalSliceStage),
  for (final stage in initialCampaign.stages)
    if (authoredPuzzlesByStageId.containsKey(stage.id))
      stage.id: _authoredRuntime(stage, authoredPuzzlesByStageId[stage.id]!),
});

/// Independent random generation for new attempts. Saved V4 uses its old catalog.
final challengeDiscoveryRuntimeCatalog = DiscoveryRuntimeCatalog({
  verticalSliceStage.id: discoveryRuntimeCatalog.resolve(verticalSliceStage),
  for (final stage in initialCampaign.stages)
    if (authoredPuzzlesByStageId.containsKey(stage.id))
      stage.id: _authoredRuntime(
        DiscoveryChallengeProfile.stageFor(stage),
        authoredPuzzlesByStageId[stage.id]!,
      ),
});

/// Checkpoints without a rules version replay the original authored fixtures.
final legacyDiscoveryRuntimeCatalog = DiscoveryRuntimeCatalog({
  verticalSliceStage.id: discoveryRuntimeCatalog.resolve(verticalSliceStage),
  for (final stage in r1LegacyStagesById.values)
    stage.id: _authoredRuntime(stage, r1PuzzlesByStageId[stage.id]!),
});

DiscoveryStageRuntime _authoredRuntime(StageDefinition stage, Puzzle puzzle) {
  final power = stage.boardMechanicPlan.bindings
      .map((binding) => binding.rule)
      .whereType<LinePowerRule>()
      .firstOrNull;
  final blocker = stage.boardMechanicPlan.bindings
      .map((binding) => binding.rule)
      .whereType<AdjacentHitBlockerRule>()
      .firstOrNull;
  final requiredKind = switch (power?.lesson) {
    BoardPowerLesson.line => DiscoveryLinePower.row,
    BoardPowerLesson.burst => DiscoveryLinePower.burst,
    BoardPowerLesson.color => DiscoveryLinePower.color,
    _ => null,
  };
  final fixtures = <String, AuthoredDiscoveryFixture>{};
  AuthoredDiscoveryFixture fixture(BoardLayoutVariant variant) {
    if (variant.fixtureId.endsWith('-random5') &&
        !fixtures.containsKey(variant.fixtureId) &&
        fixtures.length >= 4) {
      fixtures.remove(fixtures.keys.first);
    }
    return fixtures.putIfAbsent(
      variant.fixtureId,
      () => AuthoredDiscoveryFixture.create(
        stage: stage,
        puzzle: puzzle,
        variant: variant,
      ),
    );
  }

  return DiscoveryStageRuntime(
    puzzle: puzzle,
    gemKeys: AuthoredDiscoveryFixture.gemKeys,
    enableLinePowers: stage.boardMechanicPlan.mechanicIds.contains(
      BoardMechanicId.linePower,
    ),
    requiredLinePowerActivations: power?.requiredActivations ?? 0,
    enableBurstPowers: power?.enableBurst ?? false,
    enableColorPowers: power?.enableColor ?? false,
    enablePowerCombinations: power?.enableCombinations ?? false,
    requiredPowerKind: requiredKind,
    requiredCombinationActivations:
        power?.lesson == BoardPowerLesson.combination ? 1 : 0,
    requiredBlockerClears: blocker?.blockerCount ?? 0,
    buildBoard: (variant) => fixture(variant).board,
    objectivesFor: (variant) => fixture(variant).objectives,
    targetDropsFor: (variant) => fixture(variant).targetDrops,
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
              requiredLinePowerActivations: power?.requiredActivations ?? 0,
              enableBurstPowers: power?.enableBurst ?? false,
              enableColorPowers: power?.enableColor ?? false,
              enablePowerCombinations: power?.enableCombinations ?? false,
              requiredPowerKind: requiredKind,
              requiredCombinationActivations:
                  power?.lesson == BoardPowerLesson.combination ? 1 : 0,
              requiredBlockerClears: blocker?.blockerCount ?? 0,
              objectives: fixture(variant).objectives,
              targetDrops: fixture(variant).targetDrops,
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
