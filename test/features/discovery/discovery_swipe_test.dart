import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/core/theme/app_theme.dart';
import 'package:kvm/features/discovery/data/tutorial_discovery_fixture.dart';
import 'package:kvm/features/discovery/data/discovery_runtime_catalog.dart';
import 'package:kvm/features/discovery/domain/discovery_models.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_screen.dart';
import 'package:kvm/features/discovery/presentation/engine_discovery_puzzle_view_model.dart';

Finder _gems() =>
    find.descendant(of: find.byType(GridView), matching: find.byType(InkWell));

Future<void> _mount(
  WidgetTester tester,
  EngineDiscoveryPuzzleViewModel model, {
  bool reduceMotion = false,
  Size size = const Size(800, 360),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: DiscoveryPuzzleScreen(viewModel: model),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _swipeStep(
  WidgetTester tester,
  EngineDiscoveryPuzzleViewModel model,
  DiscoveryTutorialStep step, {
  bool blocked = false,
}) async {
  final from = step.from.row * model.boardColumns + step.from.column;
  final to = step.to.row * model.boardColumns + step.to.column;
  final delta =
      tester.getCenter(_gems().at(to)) - tester.getCenter(_gems().at(from));
  await tester.drag(_gems().at(from), delta, warnIfMissed: !blocked);
  await tester.pump();
}

void main() {
  testWidgets('swipe and two taps produce the same saved turn', (tester) async {
    final swipeModel = EngineDiscoveryPuzzleViewModel(
      boardConfig: DiscoveryBoardConfig.compactPhone,
    );
    final tapModel = EngineDiscoveryPuzzleViewModel(
      boardConfig: DiscoveryBoardConfig.compactPhone,
    );
    addTearDown(swipeModel.dispose);
    addTearDown(tapModel.dispose);
    await _mount(tester, swipeModel);
    final step = DiscoveryTutorialFixture.steps.first;
    await _swipeStep(tester, swipeModel, step);
    tapModel.selectGem(
      step.from.row * tapModel.boardColumns + step.from.column,
    );
    tapModel.selectGem(step.to.row * tapModel.boardColumns + step.to.column);
    expect(swipeModel.boardTurnMotion?.accepted, isTrue);
    expect(find.text('봉인이 열리고 있어요. 조각이 도착하면 식을 만들어요.'), findsOneWidget);
    expect(
      jsonEncode(swipeModel.exportSession()),
      jsonEncode(tapModel.exportSession()),
    );
    final checkpoint = jsonEncode(swipeModel.exportSession());
    await _swipeStep(tester, swipeModel, step, blocked: true);
    expect(jsonEncode(swipeModel.exportSession()), checkpoint);
    await tester.pumpAndSettle();
    expect(find.text(swipeModel.feedbackMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edge swipe does not wrap rows or spend a move', (tester) async {
    final model = EngineDiscoveryPuzzleViewModel(
      boardConfig: DiscoveryBoardConfig.compactPhone,
    );
    addTearDown(model.dispose);
    await _mount(tester, model);
    final before = jsonEncode(model.exportSession());
    await tester.drag(_gems().first, const Offset(-55, 0));
    await tester.pumpAndSettle();
    expect(jsonEncode(model.exportSession()), before);
    await tester.drag(_gems().at(model.boardColumns - 1), const Offset(55, 0));
    await tester.pumpAndSettle();
    expect(jsonEncode(model.exportSession()), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'short swipe includes gesture recognition distance on compact screen',
    (tester) async {
      final model = EngineDiscoveryPuzzleViewModel(
        boardConfig: DiscoveryBoardConfig.compactPhone,
      );
      addTearDown(model.dispose);
      await _mount(tester, model, size: const Size(680, 300));
      final step = DiscoveryTutorialFixture.steps.first;
      final from = step.from.row * model.boardColumns + step.from.column;
      await tester.drag(_gems().at(from), const Offset(0, 23));
      await tester.pump();
      expect(model.boardTurnMotion?.accepted, isTrue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'swipe starts from its own cell after another cell was selected',
    (tester) async {
      final model = EngineDiscoveryPuzzleViewModel(
        boardConfig: DiscoveryBoardConfig.compactPhone,
      );
      addTearDown(model.dispose);
      await _mount(tester, model, reduceMotion: true);
      await tester.tap(_gems().last);
      await tester.pumpAndSettle();
      expect(model.selectedCellIndex, model.boardRows * model.boardColumns - 1);
      final step = DiscoveryTutorialFixture.steps.first;
      await _swipeStep(tester, model, step);
      expect(model.boardTurnMotion?.accepted, isTrue);
      expect(model.selectedCellIndex, isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
