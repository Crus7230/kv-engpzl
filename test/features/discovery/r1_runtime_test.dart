import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/campaign/data/r1_authored_campaign.dart';
import 'package:kvm/features/campaign/domain/campaign_models.dart';
import 'package:kvm/features/discovery/data/discovery_runtime_catalog.dart';
import 'package:kvm/features/discovery/domain/discovery_engine.dart';
import 'package:kvm/features/discovery/domain/discovery_hint_solver.dart';
import 'package:kvm/features/discovery/domain/discovery_models.dart';
import 'package:kvm/features/discovery/domain/discovery_piece_source.dart';
import 'package:kvm/features/discovery/presentation/engine_discovery_puzzle_view_model.dart';
import 'package:kvm/features/puzzle/domain/equation_token.dart';
import 'package:kvm/features/puzzle/domain/puzzle.dart';

List<EquationToken> _answerTokens(StageDefinition stage, Puzzle puzzle) {
  final remaining = [...puzzle.tokens];
  return [
    for (final match in RegExp(
      r'\d+|[+\-×÷()]',
    ).allMatches(stage.answerExpression))
      remaining.removeAt(
        remaining.indexWhere((token) => token.label == match.group(0)),
      ),
  ];
}

String _boardShape(DiscoveryBoard board) => board.cells
    .map((row) => row.map((cell) => cell.piece!.matchKey).join())
    .join('/');

void main() {
  test('all 120 R1/R2 stages have registered executable runtime', () {
    expect(r1PuzzlesByStageId.length, 60);
    final authored = initialCampaign.stages.where((stage) => stage.isPlayable);
    expect(
      authored.map((stage) => stage.id).toSet(),
      authoredPuzzlesByStageId.keys.toSet(),
    );
    expect(discoveryRuntimeCatalog.contains(verticalSliceStage.id), isTrue);
    for (final stage in authored) {
      expect(stage.assistRules.tutorialMode, isNot(StageTutorialMode.forced));
      expect(stage.boardVariants.variants.length, 2);
    }
  });

  for (final id in authoredPuzzlesByStageId.keys) {
    final stage = initialCampaign.stageById(id)!;
    for (final variant in stage.boardVariants.variants) {
      final label = '${variant.config.rows}x${variant.config.columns}';
      test('$id $label: verified route, AST and exact session replay', () {
        final runtime = discoveryRuntimeCatalog.resolve(stage);
        final board = runtime.buildBoard(variant);
        expect(board.isFull, isTrue);
        expect(
          board.visiblePieces.map((p) => p.id).toSet().length,
          variant.config.rows * variant.config.columns,
        );
        expect(
          board.buriedTargets.map((p) => p.id).toSet(),
          stage.buriedTokenIds,
        );
        final path = runtime.referencePathFor!(variant);
        expect(path.length, lessThanOrEqualTo(stage.moveBudget.referenceMoves));
        expect(path.length, lessThanOrEqualTo(stage.moveBudget.parMoves));
        final engine = DiscoveryEngine(
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
          refillSource: QueuedPieceSource(
            pieces: runtime.refillPieces(variant),
            fallback: SeededGemPieceSource(
              seed: variant.seed,
              gemKeys: runtime.gemKeys,
            ),
          ),
        );
        expect(engine.state.hasAvailableMove, isTrue);
        for (final step in path) {
          final turn = engine.swap(step.from, step.to);
          expect(turn.isAccepted, isTrue);
          if (step.targetId.isNotEmpty)
            expect(
              turn.newlyDiscoveredTargets.any((p) => p.id == step.targetId),
              isTrue,
            );
        }
        expect(engine.state.isCompleted, isTrue);
        expect(engine.state.movesRemaining, stage.moveLimit - path.length);
        final orderedTokens = _answerTokens(stage, runtime.puzzle);
        expect(
          const PuzzleValidator()
              .validate(runtime.puzzle, orderedTokens)
              .isCorrect,
          isTrue,
        );

        final source = EngineDiscoveryPuzzleViewModel(
          boardConfig: variant.config,
          stage: stage,
        );
        final restored = EngineDiscoveryPuzzleViewModel(
          boardConfig: variant.config,
          stage: stage,
        );
        addTearDown(source.dispose);
        addTearDown(restored.dispose);
        void swap(
          EngineDiscoveryPuzzleViewModel model,
          DiscoveryTutorialStep step,
        ) {
          model.selectGem(
            step.from.row * model.boardColumns + step.from.column,
          );
          model.selectGem(step.to.row * model.boardColumns + step.to.column);
        }

        swap(source, path.first);
        restored.restoreSession(
          jsonDecode(jsonEncode(source.exportSession()))
              as Map<String, dynamic>,
        );
        expect(restored.exportSession(), source.exportSession());
        for (final step in path.skip(1)) {
          swap(source, step);
          swap(restored, step);
        }
        expect(restored.exportSession(), source.exportSession());
        expect(
          source.discoveredBlocks.map((b) => b.id).toSet(),
          runtime.puzzle.requiredTokenIds,
        );
        for (final token in orderedTokens) {
          source.addBlockToAnswer(token.id);
        }
        restored.restoreSession(
          jsonDecode(jsonEncode(source.exportSession()))
              as Map<String, dynamic>,
        );
        for (final model in [source, restored]) {
          model.checkAnswer();
          expect(model.isAnswerCorrect, isTrue);
          expect(model.attemptMetrics.usedGuidedCompletion, isFalse);
          expect(model.attemptMetrics.usedDirectPathHint, isFalse);
          expect(model.attemptMetrics.meaningfulSubmissionCount, 1);
        }
        expect(restored.exportSession(), source.exportSession());
      });
    }
  }

  test('authored stages do not share an identical gem board', () {
    for (final config in [
      DiscoveryBoardConfig.compactPhone,
      DiscoveryBoardConfig.standardPhone,
    ]) {
      final shapes = <String>{};
      for (final id in r1PuzzlesByStageId.keys) {
        final stage = initialCampaign.stageById(id)!;
        final variant = stage.boardVariants.variantFor(config);
        shapes.add(
          _boardShape(
            discoveryRuntimeCatalog.resolve(stage).buildBoard(variant),
          ),
        );
      }
      expect(shapes.length, 60);
    }
  });

  test('free-play accepts legal swaps outside the verification route', () {
    var foundAlternative = false;
    for (final id in r1PuzzlesByStageId.keys) {
      final stage = initialCampaign.stageById(id)!;
      final variant = stage.boardVariants.variantFor(
        DiscoveryBoardConfig.compactPhone,
      );
      final runtime = discoveryRuntimeCatalog.resolve(stage);
      final first = runtime.referencePathFor!(variant).first;
      final model = EngineDiscoveryPuzzleViewModel(
        boardConfig: variant.config,
        stage: stage,
      );
      addTearDown(model.dispose);
      for (final from in runtime.buildBoard(variant).positions) {
        for (final to in [
          DiscoveryPosition(from.row, from.column + 1),
          DiscoveryPosition(from.row + 1, from.column),
        ]) {
          if (to.row >= model.boardRows ||
              to.column >= model.boardColumns ||
              (from == first.from && to == first.to) ||
              (from == first.to && to == first.from)) {
            continue;
          }
          model.resetRound();
          model.selectGem(from.row * model.boardColumns + from.column);
          model.selectGem(to.row * model.boardColumns + to.column);
          if (model.attemptMetrics.movesUsed == 1) {
            foundAlternative = true;
            break;
          }
        }
        if (foundAlternative) break;
      }
      if (foundAlternative) break;
    }
    expect(foundAlternative, isTrue);
  });

  test('board hints use the current deviated board and do not mutate it', () {
    var checkedHints = 0;
    for (final id in r1PuzzlesByStageId.keys) {
      final stage = initialCampaign.stageById(id)!;
      final runtime = discoveryRuntimeCatalog.resolve(stage);
      for (final variant in stage.boardVariants.variants) {
        final model = EngineDiscoveryPuzzleViewModel(
          boardConfig: variant.config,
          stage: stage,
        );
        addTearDown(model.dispose);
        final reference = runtime.referencePathFor!(variant).first;
        final legal = DiscoveryBoardHintSolver.legalSwaps(
          runtime.buildBoard(variant),
        );
        final alternative = legal.firstWhere(
          (move) => !(move.from == reference.from && move.to == reference.to),
          orElse: () => legal.first,
        );
        model.selectGem(
          alternative.from.row * model.boardColumns + alternative.from.column,
        );
        model.selectGem(
          alternative.to.row * model.boardColumns + alternative.to.column,
        );
        final before = model.exportSession();
        final swaps = [
          for (final pair in before['acceptedSwaps'] as List)
            (pair as List).cast<int>(),
        ];
        final hint = runtime.suggestSwapFor!(variant, swaps);
        if (hint == null)
          continue; // A legitimate completed/dead board has no swap hint.
        checkedHints += 1;
        expect(hint.route, isNotEmpty);
        expect(hint.route.length, lessThanOrEqualTo(3));
        final engine = DiscoveryEngine(
          initialBoard: runtime.buildBoard(variant),
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
          refillSource: SeededGemPieceSource(
            seed: variant.seed,
            gemKeys: runtime.gemKeys,
          ),
        );
        for (final pair in swaps) {
          expect(
            engine
                .swap(
                  DiscoveryPosition(
                    pair[0] ~/ model.boardColumns,
                    pair[0] % model.boardColumns,
                  ),
                  DiscoveryPosition(
                    pair[1] ~/ model.boardColumns,
                    pair[1] % model.boardColumns,
                  ),
                )
                .isAccepted,
            isTrue,
          );
        }
        for (final pair in hint.route) {
          expect(engine.swap(pair.from, pair.to).isAccepted, isTrue);
        }
        if (hint.targetId != null) {
          expect(engine.state.collectedTargetIds, contains(hint.targetId));
          expect(hint.movesToTarget, hint.route.length);
        }
        model.revealHint();
        final after = model.exportSession();
        expect(after['boardState'], before['boardState']);
        expect(after['acceptedSwaps'], before['acceptedSwaps']);
        expect(after['answerTokenIds'], before['answerTokenIds']);
        expect(model.attemptMetrics.usedDirectPathHint, isTrue);
        expect(model.attemptMetrics.highestMathHintTierUsed, 0);
        expect(
          model.feedbackMessage,
          contains('${hint.from.row + 1}행 ${hint.from.column + 1}열'),
        );
      }
    }
    expect(checkedHints, greaterThan(30));
  });

  test('bounded hint fallback promises only a legal match', () {
    final stage = initialCampaign.stageById('r01-c01-s01')!;
    final runtime = discoveryRuntimeCatalog.resolve(stage);
    final variant = stage.boardVariants.variants.first;
    DiscoveryEngine replay(List<DiscoverySwapPair> swaps) {
      final engine = DiscoveryEngine(
        initialBoard: runtime.buildBoard(variant),
        requiredTargetIds: stage.buriedTokenIds,
        moves: stage.moveLimit,
        refillSource: SeededGemPieceSource(
          seed: variant.seed,
          gemKeys: runtime.gemKeys,
        ),
      );
      for (final swap in swaps) {
        engine.swap(swap.from, swap.to);
      }
      return engine;
    }

    final hint = const DiscoveryBoardHintSolver(
      maxEvaluatedSwaps: 1,
    ).suggest(replay: replay)!;
    expect(replay(const []).swap(hint.from, hint.to).isAccepted, isTrue);
    if (hint.targetId == null) {
      expect(hint.movesToTarget, isNull);
      expect(hint.route.length, 1);
    }
  });

  test(
    'every advanced turn restores layers, generated powers and activation goals',
    () {
      var sawTwoLayers = false;
      var sawGeneratedPower = false;
      var sawActivation = false;
      for (final id in ['r01-c05-s01', 'r01-c05-s06', 'r01-c06-s10']) {
        final stage = initialCampaign.stageById(id)!;
        final runtime = discoveryRuntimeCatalog.resolve(stage);
        for (final variant in stage.boardVariants.variants) {
          final source = EngineDiscoveryPuzzleViewModel(
            boardConfig: variant.config,
            stage: stage,
          );
          addTearDown(source.dispose);
          sawTwoLayers =
              sawTwoLayers || source.boardCells.any((c) => c.sealLayers == 2);
          for (final step in runtime.referencePathFor!(variant)) {
            source.selectGem(
              step.from.row * source.boardColumns + step.from.column,
            );
            source.selectGem(
              step.to.row * source.boardColumns + step.to.column,
            );
            final saved =
                jsonDecode(jsonEncode(source.exportSession()))
                    as Map<String, dynamic>;
            sawGeneratedPower =
                sawGeneratedPower ||
                source.boardCells.any((c) => c.linePowerKind != null);
            final state = saved['boardState'] as Map<String, dynamic>;
            sawActivation =
                sawActivation ||
                (state['linePowerActivations'] as int? ?? 0) > 0;
            final restored = EngineDiscoveryPuzzleViewModel(
              boardConfig: variant.config,
              stage: stage,
            );
            addTearDown(restored.dispose);
            restored.restoreSession(saved);
            expect(restored.exportSession(), source.exportSession());
            expect(
              restored.boardCells
                  .map((c) => (c.sealLayers, c.linePowerKind))
                  .toList(),
              source.boardCells
                  .map((c) => (c.sealLayers, c.linePowerKind))
                  .toList(),
            );
          }
        }
      }
      expect(sawTwoLayers, isTrue);
      expect(sawGeneratedPower, isTrue);
      expect(sawActivation, isTrue);
    },
  );
}
