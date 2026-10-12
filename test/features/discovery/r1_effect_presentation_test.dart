import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/core/theme/app_theme.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/campaign/data/r1_authored_campaign.dart';
import 'package:kvm/features/discovery/data/discovery_runtime_catalog.dart';
import 'package:kvm/features/discovery/domain/discovery_models.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_screen.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_view_model.dart';
import 'package:kvm/features/discovery/presentation/engine_discovery_puzzle_view_model.dart';
import 'package:kvm/features/puzzle/domain/equation_token.dart';

EngineDiscoveryPuzzleViewModel _model(String id) =>
    EngineDiscoveryPuzzleViewModel(
      boardConfig: DiscoveryBoardConfig.compactPhone,
      stage: initialCampaign.stageById(id)!,
    );

List<DiscoveryTutorialStep> _path(EngineDiscoveryPuzzleViewModel model) =>
    discoveryRuntimeCatalog.resolve(model.stage).referencePathFor!(
      model.stage.boardVariants.variantFor(DiscoveryBoardConfig.compactPhone),
    );

void _swap(EngineDiscoveryPuzzleViewModel model, DiscoveryTutorialStep step) {
  model.selectGem(step.from.row * model.boardColumns + step.from.column);
  model.selectGem(step.to.row * model.boardColumns + step.to.column);
}

Future<void> _show(
  WidgetTester tester,
  EngineDiscoveryPuzzleViewModel model,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(680, 300);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.3),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: DiscoveryPuzzleScreen(viewModel: model),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Finder _sealSemantics(int layers) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.label?.contains('$layers층 봉인') == true,
);

void main() {
  testWidgets(
    'actual two-layer cells show layer badges and accessible seal meaning',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final model = _model('r01-c04-s01');
        addTearDown(model.dispose);
        await _show(tester, model);
        final layers = model.boardCells.where((c) => c.sealLayers == 2).length;
        expect(_sealSemantics(2), findsNWidgets(layers));
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                RegExp(r'^\d+행 \d+열,').hasMatch(widget.properties.label ?? ''),
          ),
          findsNWidgets(25),
        );
        final twoLayerNodes = tester.widgetList<Semantics>(_sealSemantics(2));
        expect(
          twoLayerNodes.every((node) => node.properties.button == true),
          isTrue,
        );
        final badge = find.descendant(
          of: _sealSemantics(2),
          matching: find.text('2'),
        );
        expect(badge, findsNWidgets(layers));
        var sawRemainingLayer = false;
        for (final step in _path(model)) {
          _swap(model, step);
          if (model.boardCells.any((c) => c.sealLayers == 1)) {
            sawRemainingLayer = true;
            break;
          }
        }
        await tester.pumpAndSettle();
        expect(
          _sealSemantics(2),
          findsNWidgets(
            model.boardCells.where((c) => c.sealLayers == 2).length,
          ),
        );
        expect(sawRemainingLayer, isTrue);
        expect(find.byTooltip('이 스테이지 처음부터 다시 도전'), findsOneWidget);
        await tester.tap(find.byTooltip('이 스테이지 처음부터 다시 도전'));
        await tester.pumpAndSettle();
        expect(model.movesLeft, model.stage.moveLimit);
        expect(_sealSemantics(2), findsNWidgets(layers));
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets(
    'generated line powers display the same direction as live engine cells',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        var sawPower = false;
        for (var number = 6; number <= 10; number++) {
          final model = _model('r01-c05-s${number.toString().padLeft(2, '0')}');
          addTearDown(model.dispose);
          for (final step in _path(model)) {
            _swap(model, step);
            if (!model.boardCells.any((c) => c.linePowerKind != null)) continue;
            await _show(tester, model);
            for (final direction in DiscoveryLinePowerKind.values) {
              final cells = model.boardCells
                  .where((c) => c.linePowerKind == direction)
                  .length;
              final label = switch (direction) {
                DiscoveryLinePowerKind.row => '가로 직선 파워',
                DiscoveryLinePowerKind.column => '세로 직선 파워',
                DiscoveryLinePowerKind.burst => 'L/T형 범위 폭발',
                DiscoveryLinePowerKind.color => '5매치 색상 파워',
              };
              final nodes = find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    widget.properties.label?.contains(label) == true,
              );
              expect(nodes, findsNWidgets(cells));
              expect(
                find.descendant(
                  of: nodes,
                  matching: find.byIcon(switch (direction) {
                    DiscoveryLinePowerKind.row => Icons.swap_horiz_rounded,
                    DiscoveryLinePowerKind.column => Icons.swap_vert_rounded,
                    DiscoveryLinePowerKind.burst => Icons.flare_rounded,
                    DiscoveryLinePowerKind.color => Icons.palette_rounded,
                  }),
                ),
                findsNWidgets(cells),
              );
              if (cells > 0) sawPower = true;
            }
            expect(tester.takeException(), isNull);
            break;
          }
        }
        expect(sawPower, isTrue);
        // Generated directions depend on the fixture, not an unproven promise
        // that this small stage sample happens to create both orientations.
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets(
    'all tokens alone do not bypass power goal and hint explains activation',
    (tester) async {
      final stage = initialCampaign.stageById('r01-c01-s04')!;
      final puzzle = r1PuzzlesByStageId[stage.id]!;
      const keys = [
        ['A', 'A', 'B', 'A', 'C'],
        ['D', 'E', 'A', 'B', 'D'],
        ['B', 'C', 'D', 'E', 'A'],
        ['C', 'D', 'E', 'A', 'B'],
        ['E', 'B', 'C', 'D', 'E'],
      ];
      final buried = puzzle.tokens
          .where((t) => stage.buriedTokenIds.contains(t.id))
          .toList();
      final runtime = DiscoveryStageRuntime(
        puzzle: puzzle,
        buildBoard: (_) => DiscoveryBoard.fromRows(
          [
            for (var row = 0; row < 5; row++)
              [
                for (var column = 0; column < 5; column++)
                  DiscoveryPiece.gem(
                    id: 'ui-$row-$column',
                    gemKey: keys[row][column],
                  ),
              ],
          ],
          buriedTargets: {
            for (var index = 0; index < buried.length; index++)
              DiscoveryPosition(
                0,
                index,
              ): buried[index].kind == EquationTokenKind.number
                  ? DiscoveryPiece.numberToken(
                      id: buried[index].id,
                      label: buried[index].label,
                    )
                  : DiscoveryPiece.operatorToken(
                      id: buried[index].id,
                      label: buried[index].label,
                    ),
          },
        ),
        refillPieces: (_) => const [
          DiscoveryPiece.gem(id: 'ui-refill-0', gemKey: 'D'),
          DiscoveryPiece.gem(id: 'ui-refill-1', gemKey: 'C'),
          DiscoveryPiece.gem(id: 'ui-refill-2', gemKey: 'D'),
        ],
        gemKeys: const ['A', 'B', 'C', 'D', 'E'],
        enableLinePowers: true,
        requiredLinePowerActivations: 1,
      );
      final model = EngineDiscoveryPuzzleViewModel(
        boardConfig: DiscoveryBoardConfig.compactPhone,
        stage: stage,
        runtimeCatalog: DiscoveryRuntimeCatalog({stage.id: runtime}),
      );
      addTearDown(model.dispose);
      model.selectGem(7);
      model.selectGem(2);
      expect(model.discoveredBlocks.length, model.requiredBlockCount);
      for (final id in r1AnswerTokenIdsByStageId[model.stage.id]!)
        model.addBlockToAnswer(id);
      expect(model.canCheckAnswer, isFalse);
      await _show(tester, model);
      await tester.tap(find.byTooltip('힌트 보기'));
      await tester.pumpAndSettle();
      expect(model.feedbackMessage, contains('활성'));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.liveRegion == true &&
              widget.properties.label?.contains('활성') == true,
        ),
        findsOneWidget,
      );
      model.checkAnswer();
      expect(model.isAnswerCorrect, isFalse);
      model.selectGem(2);
      model.selectGem(3);
      expect(model.canCheckAnswer, isTrue);
      model.checkAnswer();
      await tester.pumpAndSettle();
      expect(model.isAnswerCorrect, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'layer introduction and guidance expose a first-turn partial seal in both layouts',
    () {
      for (final id in ['r01-c04-s01']) {
        final stage = initialCampaign.stageById(id)!;
        final runtime = discoveryRuntimeCatalog.resolve(stage);
        for (final variant in stage.boardVariants.variants) {
          final model = EngineDiscoveryPuzzleViewModel(
            boardConfig: variant.config,
            stage: stage,
          );
          addTearDown(model.dispose);
          final path = runtime.referencePathFor!(variant);
          _swap(model, path.first);
          final partialIndices = [
            for (var index = 0; index < model.boardCells.length; index++)
              if (model.boardCells[index].sealLayers == 1) index,
          ];
          expect(
            partialIndices,
            isNotEmpty,
            reason: '$id ${variant.fixtureId}',
          );
          final boardState =
              model.exportSession()['boardState'] as Map<String, dynamic>;
          final cells = (boardState['cells'] as List)
              .expand((row) => row as List)
              .toList();
          final partialTargetIds = partialIndices
              .map((index) => (cells[index] as Map)['targetId'] as String)
              .toSet();
          expect(
            model.discoveredBlocks
                .map((block) => block.id)
                .toSet()
                .intersection(partialTargetIds),
            isEmpty,
          );
          for (final step in path.skip(1)) _swap(model, step);
          expect(
            model.discoveredBlocks
                .map((block) => block.id)
                .toSet()
                .containsAll(partialTargetIds),
            isTrue,
          );
        }
      }
    },
  );
}
