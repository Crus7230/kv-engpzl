import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/discovery/data/discovery_excavation_profile.dart';
import 'package:kvm/features/discovery/domain/discovery_engine.dart';
import 'package:kvm/features/discovery/domain/discovery_hint_solver.dart';
import 'package:kvm/features/discovery/domain/discovery_models.dart';
import 'package:kvm/features/discovery/domain/discovery_piece_source.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_screen.dart';
import 'package:kvm/features/discovery/presentation/engine_discovery_puzzle_view_model.dart';
import 'package:kvm/features/discovery/presentation/stage_session_controller.dart';
import 'package:kvm/features/progress/data/progress_repository.dart';

DiscoveryBoard _board({int ice = 0}) {
  const keys = ['A', 'B', 'C', 'D', 'E'];
  final rows = [
    for (var r = 0; r < 5; r++)
      [
        for (var c = 0; c < 5; c++)
          DiscoveryPiece.gem(id: 'gem-$r-$c', gemKey: keys[(r + c) % 5]),
      ],
  ];
  void set(int r, int c, String key) =>
      rows[r][c] = DiscoveryPiece.gem(id: 'gem-$r-$c', gemKey: key);
  set(2, 0, 'B');
  set(2, 1, 'B');
  set(2, 2, 'A');
  set(2, 3, 'D');
  set(2, 4, 'E');
  set(3, 2, 'B');
  return DiscoveryBoard.fromRows(
    rows,
    buriedTargets: {
      if (ice > 0)
        const DiscoveryPosition(1, 1): const DiscoveryPiece.numberToken(
          id: 'ice-token',
          label: '7',
        ),
    },
    iceLayers: {if (ice > 0) const DiscoveryPosition(1, 1): ice},
  );
}

void main() {
  test(
    'a goal-progress hint identifies the goal without changing live state',
    () {
      DiscoveryEngine replay(List<DiscoverySwapPair> swaps) {
        final engine = DiscoveryEngine(
          initialBoard: _board(),
          requiredTargetIds: const {},
          moves: 12,
          refillSource: SeededGemPieceSource(seed: 7),
          objectives: const [
            DiscoveryObjective(
              id: 'blue',
              label: '파란 보석',
              kind: DiscoveryObjectiveKind.color,
              matchKey: 'B',
              goal: 3,
            ),
          ],
        );
        for (final move in swaps) {
          engine.swap(move.from, move.to);
        }
        return engine;
      }

      final live = replay(const []);
      final hint = const DiscoveryBoardHintSolver().suggest(replay: replay)!;
      expect(hint.objectiveLabel, '파란 보석');
      expect(hint.targetId, isNull);
      expect(live.state.acceptedMoves, 0);
      expect(live.state.objectiveProgress['blue'] ?? 0, 0);
      expect(
        replay(hint.route).state.objectiveProgress['blue'],
        greaterThanOrEqualTo(3),
      );
    },
  );

  test('compound goals are ANDed and color reward is awarded once', () {
    final engine = DiscoveryEngine(
      initialBoard: _board(),
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
    final turn = engine.swap(
      const DiscoveryPosition(3, 2),
      const DiscoveryPosition(2, 2),
    );
    expect(turn.isAccepted, isTrue);
    expect(turn.state.collectedTargetIds, contains('reward'));
    expect(turn.state.isCompleted, isFalse);
    expect(
      turn.newlyDiscoveredTargets.where((p) => p.id == 'reward').length,
      1,
    );
    expect(
      turn.state.clearedByColor['B'],
      turn.cascades
          .expand((c) => c.clearedPieces)
          .where((p) => p.piece.matchKey == 'B')
          .length,
    );
  });

  test('ice is immovable and loses at most one layer per cascade', () {
    final engine = DiscoveryEngine(
      initialBoard: _board(ice: 2),
      requiredTargetIds: const {'ice-token'},
      moves: 12,
      refillSource: SeededGemPieceSource(seed: 7),
    );
    final blocked = engine.swap(
      const DiscoveryPosition(1, 1),
      const DiscoveryPosition(1, 2),
    );
    expect(blocked.status, DiscoverySwapStatus.blocked);
    expect(engine.state.acceptedMoves, 0);
    final turn = engine.swap(
      const DiscoveryPosition(3, 2),
      const DiscoveryPosition(2, 2),
    );
    final hit = turn.cascades.first.iceHits.single;
    expect(hit.layersBefore, 2);
    expect(hit.layersAfter, 1);
    expect(turn.cascades.first.discoveredTargets, isEmpty);
  });

  test('invalid swaps do not advance incoming fragments', () {
    final engine = DiscoveryEngine(
      initialBoard: _board(),
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
    engine.swap(const DiscoveryPosition(0, 0), const DiscoveryPosition(0, 0));
    expect(engine.state.acceptedMoves, 0);
    engine.swap(const DiscoveryPosition(3, 2), const DiscoveryPosition(2, 2));
    expect(engine.state.pendingDrops.length, 1);
    expect(engine.state.collectedTargetIds, isEmpty);
    expect(
      engine.state.board.visiblePieces.any(
        (piece) => piece.carriedTarget != null,
      ),
      isFalse,
    );
  });

  for (final id in ['r01-c04-s04', 'r01-c06-s01', 'r02-c06-s10']) {
    test(
      '$id v4 restores pending drops, objective counters and draft without reset',
      () {
        final stage = initialCampaign.stageById(id)!;
        final source = StageSessionController(
          repository: ProgressRepository(MemoryKeyValueSaveStore()),
          stage: stage,
          boardConfig: DiscoveryBoardConfig.standardPhone,
          newSessionRulesVersion: 4,
          onContinue: () {},
          onSaveError: (e) => fail('$e'),
        );
        addTearDown(source.dispose);
        final step = source.referencePath.first;
        source.selectGem(
          step.from.row * source.boardColumns + step.from.column,
        );
        source.selectGem(step.to.row * source.boardColumns + step.to.column);
        source.addBlockToAnswer(source.discoveredBlocks.first.id);
        final checkpoint = {
          ...source.exportSession(),
          'attemptId': source.attemptId,
        };
        final restored = StageSessionController(
          repository: ProgressRepository(MemoryKeyValueSaveStore()),
          stage: stage,
          boardConfig: DiscoveryBoardConfig.standardPhone,
          savedSession: checkpoint,
          onContinue: () {},
          onSaveError: (e) => fail('$e'),
        );
        addTearDown(restored.dispose);
        expect(restored.rulesVersion, 4);
        expect(restored.exportSession(), source.exportSession());
        expect(restored.attemptId, source.attemptId);
      },
    );
  }

  for (final size in [const Size(680, 300), const Size(800, 360)]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'all compound objectives fit ${size.width}x${size.height} scale $scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final stage = initialCampaign.stageById('r01-c06-s01')!;
          final model = EngineDiscoveryPuzzleViewModel(
            stage: stage,
            rulesVersion: 4,
            boardConfig: DiscoveryExcavationProfile.boardFor(
              stage,
              size.width,
              size.height,
            ),
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
          expect(find.byTooltip('파란 보석 · 0/20'), findsOneWidget);
          expect(find.byTooltip('초록 보석 · 0/12'), findsOneWidget);
          expect(model.boardCells.length, model.boardRows * model.boardColumns);
        },
      );
    }
  }
}
