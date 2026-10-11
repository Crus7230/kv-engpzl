import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/campaign/domain/campaign_models.dart';
import 'package:kvm/features/discovery/data/discovery_runtime_catalog.dart';
import 'package:kvm/features/discovery/data/tutorial_discovery_fixture.dart';
import 'package:kvm/features/discovery/domain/discovery_models.dart';
import 'package:kvm/features/discovery/presentation/engine_discovery_puzzle_view_model.dart';
import 'package:kvm/features/discovery/presentation/stage_session_controller.dart';
import 'package:kvm/features/progress/progress.dart';

void discover(EngineDiscoveryPuzzleViewModel model, {int steps = 3}) {
  for (final step in DiscoveryTutorialFixture.steps.take(steps)) {
    model.selectGem(step.from.row * model.boardColumns + step.from.column);
    model.selectGem(step.to.row * model.boardColumns + step.to.column);
  }
}

void answer(EngineDiscoveryPuzzleViewModel model) {
  for (final id in ['p1-n4', 'p1-times', 'p1-n3', 'p1-plus', 'p1-n2']) {
    model.addBlockToAnswer(id);
  }
  model.checkAnswer();
}

Map<String, dynamic> cloneJson(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

class _BlockingCommitStore extends MemoryKeyValueSaveStore {
  bool holdPointer = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> write(String key, String value) async {
    if (holdPointer && key == ProgressRepository.pointerKey) {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    }
    await super.write(key, value);
  }
}

void main() {
  for (final config in [
    DiscoveryBoardConfig.compactPhone,
    DiscoveryBoardConfig.standardPhone,
  ]) {
    final label = '${config.rows}x${config.columns}';
    test(
      '$label: authored tutorial finds five unique tokens and solves 4×3+2',
      () {
        final model = EngineDiscoveryPuzzleViewModel(boardConfig: config);
        addTearDown(model.dispose);
        discover(model);
        expect(model.discoveredBlocks.map((b) => b.id).toSet(), {
          'p1-n4',
          'p1-n3',
          'p1-times',
          'p1-plus',
          'p1-n2',
        });
        expect(model.movesLeft, verticalSliceStage.moveLimit - 3);
        answer(model);
        expect(model.isAnswerCorrect, isTrue);
        expect(model.attemptMetrics.meaningfulSubmissionCount, 1);
        expect(model.attemptMetrics.firstMeaningfulSubmissionCorrect, isTrue);
        expect(model.attemptMetrics.usedGuidedCompletion, isTrue);
      },
    );

    test(
      '$label: persisted checkpoint restores exact board, tokens, expression and evidence',
      () async {
        final store = MemoryKeyValueSaveStore();
        final repository = ProgressRepository(store);
        final failures = <Object>[];
        final source = StageSessionController(
          repository: repository,
          stage: verticalSliceStage,
          boardConfig: config,
          onContinue: () {},
          onSaveError: failures.add,
        );
        addTearDown(source.dispose);
        discover(source);
        source.revealHint();
        source.addBlockToAnswer('p1-n4');
        source.addBlockToAnswer('p1-times');
        source.selectGem(0);
        await source.checkpoint();
        final saved = (await ProgressRepository(store).load()).activeSession!;
        final restored = StageSessionController(
          repository: ProgressRepository(store),
          stage: verticalSliceStage,
          boardConfig: config,
          savedSession: cloneJson(saved),
          onContinue: () {},
          onSaveError: failures.add,
        );
        addTearDown(restored.dispose);
        expect(restored.attemptId, source.attemptId);
        expect(restored.exportSession(), source.exportSession());
        expect(restored.movesLeft, source.movesLeft);
        expect(restored.score, source.score);
        expect(restored.attemptMetrics.highestMathHintTierUsed, 1);
        for (final id in ['p1-n3', 'p1-plus', 'p1-n2']) {
          restored.addBlockToAnswer(id);
        }
        restored.checkAnswer();
        await restored.flush();
        expect(restored.isAnswerCorrect, isTrue);
        expect(failures, isEmpty);
      },
    );

    test(
      '$label: mid-discovery replay continues with identical refill stream',
      () {
        final source = EngineDiscoveryPuzzleViewModel(boardConfig: config);
        final restored = EngineDiscoveryPuzzleViewModel(boardConfig: config);
        addTearDown(source.dispose);
        addTearDown(restored.dispose);
        discover(source, steps: 1);
        restored.restoreSession(cloneJson(source.exportSession()));
        for (final step in DiscoveryTutorialFixture.steps.skip(1)) {
          for (final model in [source, restored]) {
            model.selectGem(
              step.from.row * model.boardColumns + step.from.column,
            );
            model.selectGem(step.to.row * model.boardColumns + step.to.column);
          }
        }
        expect(restored.exportSession(), source.exportSession());
      },
    );
  }

  final corruptions = <String, void Function(Map<String, dynamic>)>{
    'future session version': (s) => s['sessionVersion'] = 2,
    'different stage': (s) => s['stageId'] = 'unknown-stage',
    'different fixture': (s) => s['fixtureId'] = 'unverified-fixture',
    'different board seed': (s) => s['boardSeed'] = 999,
    'malformed swap': (s) => s['acceptedSwaps'] = [
      [-1, 0],
    ],
    'unaccepted swap': (s) => s['acceptedSwaps'] = [
      [0, 1],
    ],
    'materialized board mismatch': (s) =>
        (s['boardState'] as Map<String, dynamic>)['movesRemaining'] = 99,
    'undiscovered answer token': (s) => s['answerTokenIds'] = ['p1-times'],
    'duplicate answer token': (s) => s['answerTokenIds'] = ['p1-n4', 'p1-n4'],
    'invalid hint tier': (s) => s['hintLevel'] = 4,
    'unproved completion': (s) => s['isAnswerCorrect'] = true,
    'selected cell outside board': (s) => s['selectedCellIndex'] = 1000,
  };
  for (final entry in corruptions.entries) {
    test('rejects ${entry.key} without accepting corrupted progress', () {
      final model = EngineDiscoveryPuzzleViewModel(
        boardConfig: DiscoveryBoardConfig.compactPhone,
      );
      addTearDown(model.dispose);
      final saved = cloneJson(model.exportSession());
      entry.value(saved);
      expect(() => model.restoreSession(saved), throwsFormatException);
      expect(model.isAnswerCorrect, isFalse);
    });
  }

  test('planned campaign slots cannot start a session', () {
    final planned = initialCampaign.stages.firstWhere(
      (stage) => !stage.isPlayable,
    );
    expect(planned.isPlayable, isFalse);
    expect(
      () => EngineDiscoveryPuzzleViewModel(
        boardConfig: DiscoveryBoardConfig.compactPhone,
        stage: planned,
      ),
      throwsStateError,
    );
  });

  test('unsupported board layout cannot use verified fixtures', () {
    expect(
      () => EngineDiscoveryPuzzleViewModel(
        boardConfig: const DiscoveryBoardConfig(rows: 5, columns: 6),
      ),
      throwsArgumentError,
    );
  });

  test(
    'lifecycle checkpoint during delayed completion cannot resurrect active session',
    () async {
      final store = _BlockingCommitStore();
      final repository = ProgressRepository(store);
      final model = StageSessionController(
        repository: repository,
        stage: verticalSliceStage,
        boardConfig: DiscoveryBoardConfig.compactPhone,
        onContinue: () {},
        onSaveError: (error) => fail('$error'),
      );
      addTearDown(model.dispose);
      discover(model);
      answer(model);
      model.pauseSaving();
      await model.flush();
      store.holdPointer = true;
      final completion = StageCompletionService(
        repository,
      ).complete(model.result());
      await store.entered.future;
      await model.checkpoint();
      store.release.complete();
      await completion;
      await model.checkpoint();
      final restarted = await ProgressRepository(store).load();
      expect(restarted.activeSession, isNull);
      expect(restarted.rewardLedger.length, 1);
      expect(restarted.completedStageIds, contains(verticalSliceStage.id));
    },
  );

  test('runtime catalog runs a separately registered authored stage', () {
    final original = verticalSliceStage;
    final other = StageDefinition(
      id: 'test-second-runtime',
      chapterId: original.chapterId,
      skillId: original.skillId,
      number: 2,
      title: '별도 테스트 스테이지',
      conceptLabel: original.conceptLabel,
      answerExpression: original.answerExpression,
      puzzleId: original.puzzleId,
      contentStatus: original.contentStatus,
      mathDifficulty: original.mathDifficulty,
      matchDifficulty: original.matchDifficulty,
      boardMechanicPlan: original.boardMechanicPlan,
      boardVariants: original.boardVariants,
      moveBudget: original.moveBudget,
      starRules: original.starRules,
      assistRules: original.assistRules,
      learningPlan: original.learningPlan,
      variantProfile: original.variantProfile,
      seed: original.seed,
      startingTokenIds: original.startingTokenIds,
      buriedTokenIds: original.buriedTokenIds,
    );
    final model = EngineDiscoveryPuzzleViewModel(
      boardConfig: DiscoveryBoardConfig.compactPhone,
      stage: other,
      runtimeCatalog: DiscoveryRuntimeCatalog({
        other.id: discoveryRuntimeCatalog.resolve(original),
      }),
    );
    addTearDown(model.dispose);
    discover(model);
    answer(model);
    expect(model.stage.id, other.id);
    expect(model.isAnswerCorrect, isTrue);
  });
}
