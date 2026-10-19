import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/campaign/data/r1_authored_campaign.dart';
import 'package:kvm/features/discovery/data/discovery_runtime_catalog.dart';
import 'package:kvm/features/discovery/domain/discovery_models.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_screen.dart';
import 'package:kvm/features/discovery/presentation/engine_discovery_puzzle_view_model.dart';
import 'package:kvm/features/discovery/presentation/stage_session_controller.dart';
import 'package:kvm/features/progress/data/progress_repository.dart';
import 'package:kvm/features/puzzle/domain/equation_token.dart';

void _play(EngineDiscoveryPuzzleViewModel model, DiscoveryTutorialStep step) {
  model.selectGem(step.from.row * model.boardColumns + step.from.column);
  model.selectGem(step.to.row * model.boardColumns + step.to.column);
}

void main() {
  for (final id in ['r01-c01-s02', 'r01-c04-s04', 'r02-c06-s10']) {
    test('$id v5 restores the random seed, counters and draft exactly', () {
      final stage = initialCampaign.stageById(id)!;
      final source = EngineDiscoveryPuzzleViewModel(
        stage: stage,
        rulesVersion: 5,
        boardSeed: 42,
        boardConfig: DiscoveryBoardConfig.standardPhone,
      );
      addTearDown(source.dispose);
      _play(source, source.referencePath.first);
      source.addBlockToAnswer(source.discoveredBlocks.first.id);
      final checkpoint = {...source.exportSession(), 'attemptId': 'saved-$id'};
      final restored = StageSessionController(
        repository: ProgressRepository(MemoryKeyValueSaveStore()),
        stage: stage,
        boardConfig: DiscoveryBoardConfig.standardPhone,
        savedSession: checkpoint,
        newSessionRulesVersion: 5,
        onContinue: () {},
        onSaveError: (e) => fail('$e'),
      );
      addTearDown(restored.dispose);
      expect(restored.rulesVersion, 5);
      expect(restored.exportSession(), source.exportSession());
      expect(restored.attemptId, 'saved-$id');
      expect(restored.stage.moveLimit, inInclusiveRange(15, 20));
    });
  }

  for (final version in [1, 3, 4]) {
    test('v$version checkpoint is not upgraded or randomized on restore', () {
      final stage = initialCampaign.stageById('r01-c01-s02')!;
      final source = EngineDiscoveryPuzzleViewModel(
        stage: stage,
        rulesVersion: version,
        boardConfig: DiscoveryBoardConfig.compactPhone,
      );
      addTearDown(source.dispose);
      _play(source, source.referencePath.first);
      final restored = StageSessionController(
        repository: ProgressRepository(MemoryKeyValueSaveStore()),
        stage: stage,
        boardConfig: DiscoveryBoardConfig.compactPhone,
        savedSession: {
          ...source.exportSession(),
          'attemptId': 'legacy-$version',
        },
        newSessionRulesVersion: 5,
        onContinue: () {},
        onSaveError: (e) => fail('$e'),
      );
      addTearDown(restored.dispose);
      expect(restored.rulesVersion, version);
      expect(restored.exportSession(), source.exportSession());
    });
  }

  test('retry changes seed and attempt; checkpoint restore does not', () {
    final controller = StageSessionController(
      repository: ProgressRepository(MemoryKeyValueSaveStore()),
      stage: initialCampaign.stageById('r01-c01-s02')!,
      boardConfig: DiscoveryBoardConfig.compactPhone,
      newSessionRulesVersion: 5,
      onContinue: () {},
      onSaveError: (e) => fail('$e'),
    );
    addTearDown(controller.dispose);
    final before = controller.exportSession();
    final id = controller.attemptId;
    controller.resetRound();
    expect(controller.attemptId, isNot(id));
    expect(controller.exportSession()['boardSeed'], isNot(before['boardSeed']));
    expect(controller.exportSession()['acceptedSwaps'], isEmpty);
  });

  for (final goalFirst in [false, true]) {
    test(
      goalFirst
          ? 'a completed color goal cannot bypass undiscovered fragments'
          : 'fragments and an assembled answer cannot bypass an unmet puzzle goal',
      () {
        final stage = initialCampaign.stageById('r01-c01-s02')!;
        final puzzle = authoredPuzzlesByStageId[stage.id]!;
        const keys = ['A', 'B', 'C', 'D', 'E'];
        final rows = [
          for (var r = 0; r < 5; r++)
            [
              for (var c = 0; c < 5; c++)
                DiscoveryPiece.gem(id: '$r-$c', gemKey: keys[(r + c) % 5]),
            ],
        ];
        for (final p in [
          const DiscoveryPosition(2, 0),
          const DiscoveryPosition(2, 1),
          const DiscoveryPosition(3, 2),
        ]) {
          rows[p.row][p.column] = DiscoveryPiece.gem(
            id: '${p.row}-${p.column}',
            gemKey: 'B',
          );
        }
        rows[2][2] = const DiscoveryPiece.gem(id: '2-2', gemKey: 'A');
        rows[2][3] = const DiscoveryPiece.gem(id: '2-3', gemKey: 'D');
        rows[2][4] = const DiscoveryPiece.gem(id: '2-4', gemKey: 'E');
        final tokens = [
          for (final token in puzzle.tokens)
            if (stage.buriedTokenIds.contains(token.id)) token,
        ];
        final board = DiscoveryBoard.fromRows(
          rows,
          buriedTargets: {
            for (var n = 0; n < tokens.length; n++)
              DiscoveryPosition(goalFirst ? 4 : 2, n): switch (tokens[n].kind) {
                EquationTokenKind.number => DiscoveryPiece.numberToken(
                  id: tokens[n].id,
                  label: tokens[n].label,
                ),
                EquationTokenKind.operator => DiscoveryPiece.operatorToken(
                  id: tokens[n].id,
                  label: tokens[n].label,
                ),
                _ => DiscoveryPiece.parenthesisToken(
                  id: tokens[n].id,
                  label: tokens[n].label,
                ),
              },
          },
        );
        final model = EngineDiscoveryPuzzleViewModel(
          stage: stage,
          rulesVersion: 5,
          boardConfig: DiscoveryBoardConfig.compactPhone,
          runtimeCatalog: DiscoveryRuntimeCatalog({
            stage.id: DiscoveryStageRuntime(
              puzzle: puzzle,
              gemKeys: keys,
              buildBoard: (_) => board,
              refillPieces: (_) => const [],
              objectivesFor: (_) => [
                DiscoveryObjective(
                  id: 'blue',
                  label: '파란 보석',
                  kind: DiscoveryObjectiveKind.color,
                  matchKey: 'B',
                  goal: goalFirst ? 3 : 999,
                ),
              ],
            ),
          }),
        );
        addTearDown(model.dispose);
        model.selectGem(3 * 5 + 2);
        model.selectGem(2 * 5 + 2);
        expect(
          model.discoveredBlocks.length,
          goalFirst
              ? lessThan(model.requiredBlockCount)
              : model.requiredBlockCount,
        );
        for (final block in model.discoveredBlocks.toList())
          model.addBlockToAnswer(block.id);
        expect(model.discoveryObjectives.last.isCompleted, goalFirst);
        expect(model.canCheckAnswer, isFalse);
        if (!goalFirst) {
          expect(model.feedbackMessage, contains('식 조각을 모두 놓았어요'));
          expect(model.feedbackMessage, contains('파란 보석'));
        }
        expect(model.movesLeft, greaterThan(0));
        model.checkAnswer();
        expect(model.isAnswerCorrect, isFalse);
      },
    );
  }

  for (final id in ['r01-c01-s02', 'r01-c04-s04', 'r02-c06-s10']) {
    test('$id opens submission only after both gates and checks the math', () {
      final model = EngineDiscoveryPuzzleViewModel(
        stage: initialCampaign.stageById(id)!,
        rulesVersion: 5,
        boardSeed: 42,
        boardConfig: DiscoveryBoardConfig.standardPhone,
      );
      addTearDown(model.dispose);
      expect(model.canCheckAnswer, isFalse);
      for (final step in model.referencePath) {
        _play(model, step);
      }
      expect(model.discoveredBlocks.length, model.requiredBlockCount);
      expect(
        model.discoveryObjectives.every((goal) => goal.isCompleted),
        isTrue,
      );
      expect(
        model.canCheckAnswer,
        isFalse,
        reason: 'The answer is still empty.',
      );
      for (final token in authoredPuzzlesByStageId[id]!.tokens) {
        model.addBlockToAnswer(token.id);
      }
      expect(model.canCheckAnswer, isTrue);
      model.checkAnswer();
      expect(model.isAnswerCorrect, isTrue);
    });
  }

  for (final size in [const Size(680, 300), const Size(800, 360)]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('v5 two gates fit $size scale $scale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final model = EngineDiscoveryPuzzleViewModel(
          stage: initialCampaign.stageById('r01-c06-s01')!,
          rulesVersion: 5,
          boardSeed: 202611183,
          boardConfig: DiscoveryBoardConfig.standardPhone,
        );
        addTearDown(model.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: DiscoveryPuzzleScreen(viewModel: model),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byTooltip('풀이 블록 · 0/${model.stage.buriedTokenIds.length}'),
          findsOneWidget,
        );
        expect(find.byTooltip('파란 보석 · 0/20'), findsOneWidget);
        expect(find.byTooltip('초록 보석 · 0/12'), findsOneWidget);
      });
    }
  }
}
