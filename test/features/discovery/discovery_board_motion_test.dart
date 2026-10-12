import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/core/theme/app_theme.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/discovery/data/discovery_runtime_catalog.dart';
import 'package:kvm/features/discovery/data/tutorial_discovery_fixture.dart';
import 'package:kvm/features/discovery/domain/discovery_models.dart';
import 'package:kvm/features/discovery/presentation/discovery_board_animation.dart';
import 'package:kvm/features/discovery/presentation/discovery_board_motion.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_screen.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_view_model.dart';
import 'package:kvm/features/discovery/presentation/engine_discovery_puzzle_view_model.dart';

EngineDiscoveryPuzzleViewModel _model(String id) =>
    EngineDiscoveryPuzzleViewModel(
      boardConfig: DiscoveryBoardConfig.compactPhone,
      stage: initialCampaign.stageById(id)!,
    );

void _swap(EngineDiscoveryPuzzleViewModel model, DiscoveryTutorialStep step) {
  model.selectGem(step.from.row * model.boardColumns + step.from.column);
  model.selectGem(step.to.row * model.boardColumns + step.to.column);
}

List<DiscoveryTutorialStep> _path(EngineDiscoveryPuzzleViewModel model) =>
    discoveryRuntimeCatalog.resolve(model.stage).referencePathFor!(
      model.stage.boardVariants.variantFor(
        DiscoveryBoardConfig(
          rows: model.boardRows,
          columns: model.boardColumns,
        ),
      ),
    );

List<int> _rejectedPair(EngineDiscoveryPuzzleViewModel model) {
  for (var row = 0; row < model.boardRows; row++) {
    for (var column = 0; column < model.boardColumns - 1; column++) {
      model.resetRound();
      final index = row * model.boardColumns + column;
      model.selectGem(index);
      model.selectGem(index + 1);
      if (model.boardTurnMotion?.accepted == false) return [index, index + 1];
    }
  }
  throw StateError('Fixture has no rejected adjacent swap.');
}

Finder _gridGems() =>
    find.descendant(of: find.byType(GridView), matching: find.byType(InkWell));

Finder _motionSprites() => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key as ValueKey<String>).value.startsWith('motion-gem-'),
);

Finder _sprite(String id) => find.byKey(ValueKey('motion-gem-$id'));

Finder _flight(String id) => find.byKey(ValueKey('discovery-flight-$id'));

DiscoveryMotionTimeline _timeline(EngineDiscoveryPuzzleViewModel model) =>
    discoveryMotionTimeline(
      model.boardTurnMotion!,
      columns: model.boardColumns,
    );

int _phaseStart(DiscoveryMotionTimeline timeline, DiscoveryMotionPhase phase) =>
    timeline.phases
        .takeWhile((candidate) => !identical(candidate, phase))
        .fold<int>(
          0,
          (total, candidate) => total + candidate.duration.inMilliseconds,
        );

class _PlaybackClock {
  _PlaybackClock(this.tester);

  final WidgetTester tester;
  int elapsed = 0;

  Future<void> at(int milliseconds) async {
    expect(milliseconds, greaterThanOrEqualTo(elapsed));
    await tester.pump(Duration(milliseconds: milliseconds - elapsed));
    elapsed = milliseconds;
  }
}

void _expectCardInsideBoard(WidgetTester tester, Finder flight) {
  final board = tester.getRect(find.byType(DiscoveryAnimatedGemBoard));
  final card = tester.getRect(flight);
  expect(card.left, greaterThanOrEqualTo(board.left - .5));
  expect(card.top, greaterThanOrEqualTo(board.top - .5));
  expect(card.right, lessThanOrEqualTo(board.right + .5));
  expect(card.bottom, lessThanOrEqualTo(board.bottom + .5));
}

Future<void> _tapStep(
  WidgetTester tester,
  DiscoveryPuzzleViewModel model,
  DiscoveryTutorialStep step,
) async {
  await tester.tap(
    _gridGems().at(step.from.row * model.boardColumns + step.from.column),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    _gridGems().at(step.to.row * model.boardColumns + step.to.column),
  );
  await tester.pump();
}

DiscoveryBoardInteractionLock _lock(WidgetTester tester) => tester
    .widget<DiscoveryAnimatedGemBoard>(find.byType(DiscoveryAnimatedGemBoard))
    .lock;

Future<void> _show(
  WidgetTester tester,
  DiscoveryPuzzleViewModel model, {
  bool disabled = false,
  bool settle = true,
  Size size = const Size(680, 300),
  double textScale = 1,
  EdgeInsets safePadding = EdgeInsets.zero,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disabled,
          textScaler: TextScaler.linear(textScale),
          padding: safePadding,
          viewPadding: safePadding,
        ),
        child: child!,
      ),
      home: DiscoveryPuzzleScreen(viewModel: model),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> _tapTutorialSwap(WidgetTester tester) async {
  final model = tester
      .widget<DiscoveryAnimatedGemBoard>(find.byType(DiscoveryAnimatedGemBoard))
      .viewModel;
  await _tapStep(tester, model, DiscoveryTutorialFixture.steps.first);
}

EngineDiscoveryPuzzleViewModel _twoCascadeModel(DiscoveryBoardConfig config) {
  final original = discoveryRuntimeCatalog.resolve(verticalSliceStage);
  const keys = ['A', 'A', 'A', 'B', 'C', 'D', 'A', 'B', 'C'];
  final runtime = DiscoveryStageRuntime(
    puzzle: original.puzzle,
    buildBoard: original.buildBoard,
    gemKeys: original.gemKeys,
    tutorialSteps: original.tutorialSteps,
    referencePathFor: original.referencePathFor,
    refillPieces: (variant) => [
      for (var index = 0; index < keys.length; index++)
        DiscoveryPiece.gem(
          id: '${variant.fixtureId}-chain-$index',
          gemKey: keys[index],
        ),
    ],
  );
  return EngineDiscoveryPuzzleViewModel(
    boardConfig: config,
    stage: verticalSliceStage,
    runtimeCatalog: DiscoveryRuntimeCatalog({verticalSliceStage.id: runtime}),
  );
}

void main() {
  test(
    'trace preserves fixed seals, exact final checkpoint and reset/restore',
    () {
      for (final config in [
        DiscoveryBoardConfig.compactPhone,
        DiscoveryBoardConfig.standardPhone,
      ]) {
        final model = EngineDiscoveryPuzzleViewModel(
          boardConfig: config,
          stage: initialCampaign.stageById('r01-c05-s01')!,
        );
        addTearDown(model.dispose);
        final runtime = discoveryRuntimeCatalog.resolve(model.stage);
        final step = runtime
            .referencePathFor!(model.stage.boardVariants.variantFor(config))
            .first;
        final before = List<DiscoveryGemCell>.of(model.boardCells);
        _swap(model, step);
        final trace = model.boardTurnMotion!;
        expect(trace.accepted, isTrue);
        expect(
          trace.beforeSwap.map((cell) => cell.gem!.id),
          before.map((cell) => cell.id),
        );
        expect(
          trace.afterSwap[trace.fromIndex].gem!.id,
          before[trace.toIndex].id,
        );
        for (var index = 0; index < before.length; index++) {
          expect(trace.afterSwap[index].sealLayers, before[index].sealLayers);
          expect(trace.afterSwap[index].sealKind, before[index].sealKind);
        }
        expect(
          trace.cascades
              .expand((step) => step.sealHits)
              .any((hit) => hit.layersBefore == 2 && hit.layersAfter == 1),
          isTrue,
        );
        expect(
          trace.cascades.last.afterRefill.map((cell) => cell.gem!.id),
          model.boardCells.map((cell) => cell.id),
        );
        final saved =
            jsonDecode(jsonEncode(model.exportSession()))
                as Map<String, dynamic>;
        expect(
          saved.keys.any((key) => key.toLowerCase().contains('motion')),
          isFalse,
        );
        final revision = model.boardMotionRevision;
        model.restoreSession(saved);
        expect(model.exportSession(), saved);
        expect(model.boardTurnMotion, isNull);
        expect(model.boardMotionRevision, greaterThan(revision));
        model.resetRound();
        expect(model.boardTurnMotion, isNull);
        expect(
          model.boardCells.map((cell) => cell.id),
          before.map((cell) => cell.id),
        );
      }
    },
  );

  test(
    'power sweeps precede clear, preserve direction and sequence cascades',
    () {
      final observed = <DiscoveryLinePowerKind>{};
      for (final id in [
        'r01-c01-s04',
        'r01-c02-s09',
        'r01-c02-s10',
        'r01-c04-s06',
      ]) {
        final model = _model(id);
        addTearDown(model.dispose);
        for (final step in _path(model)) {
          _swap(model, step);
          final trace = model.boardTurnMotion!;
          final timeline = discoveryMotionTimeline(
            trace,
            columns: model.boardColumns,
          );
          final phases = timeline.phases;
          expect(phases.first.kind, DiscoveryMotionPhaseKind.swap);
          for (var index = 0; index < phases.length; index++) {
            final phase = phases[index];
            if (phase.kind == DiscoveryMotionPhaseKind.powerSweep) {
              observed.addAll(
                phase.cascade!.activatedPowers.map((power) => power.direction),
              );
              expect(phases[index + 1].kind, DiscoveryMotionPhaseKind.clear);
              for (final power in phase.cascade!.activatedPowers) {
                expect(
                  power.affectedIndices.every(
                    (index) => index >= 0 && index < trace.beforeSwap.length,
                  ),
                  isTrue,
                );
                if (power.direction == DiscoveryLinePowerKind.burst ||
                    power.direction == DiscoveryLinePowerKind.color ||
                    power.isCombination) {
                  expect(power.affectedIndices, isNotEmpty);
                }
              }
            }
            if (phase.kind == DiscoveryMotionPhaseKind.clear) {
              final settle = phases[index + 1];
              expect(settle.kind, DiscoveryMotionPhaseKind.settle);
              expect(settle.before, phase.cascade!.afterClear);
              expect(settle.after, phase.cascade!.afterRefill);
            }
          }
          expect(
            phases.map((phase) => phase.kind),
            isNot(contains(DiscoveryMotionPhaseKind.fall)),
          );
          expect(
            phases.map((phase) => phase.kind),
            isNot(contains(DiscoveryMotionPhaseKind.refill)),
          );
          expect(
            phases.map((phase) => phase.kind),
            isNot(contains(DiscoveryMotionPhaseKind.discovery)),
          );
          for (final window in timeline.discoveries) {
            final clear = phases.firstWhere(
              (phase) =>
                  phase.kind == DiscoveryMotionPhaseKind.clear &&
                  identical(phase.cascade, window.cascade),
            );
            final clearStart = _phaseStart(timeline, clear);
            expect(window.start.inMilliseconds, greaterThan(clearStart));
            expect(
              window.start.inMilliseconds,
              lessThan(clearStart + clear.duration.inMilliseconds),
            );
            expect(window.duration, greaterThan(Duration.zero));
            expect(window.end, lessThanOrEqualTo(timeline.duration));
          }
          expect(
            timeline.duration,
            lessThanOrEqualTo(const Duration(seconds: 3)),
          );
        }
      }
      expect(
        observed,
        containsAll([
          DiscoveryLinePowerKind.row,
          DiscoveryLinePowerKind.burst,
          DiscoveryLinePowerKind.color,
        ]),
      );
    },
  );

  test(
    'rejected swap returns without spending a move and long chains stay bounded',
    () {
      final model = _model('r01-c05-s01');
      addTearDown(model.dispose);
      _rejectedPair(model);
      final rejected = model.boardTurnMotion!;
      expect(discoveryMotionPhases(rejected).map((phase) => phase.kind), [
        DiscoveryMotionPhaseKind.swap,
        DiscoveryMotionPhaseKind.returnSwap,
      ]);
      expect(model.movesLeft, model.stage.moveLimit);
      expect((model.exportSession()['acceptedSwaps'] as List), isEmpty);
      expect(
        rejected.beforeSwap.map((cell) => cell.gem!.id),
        model.boardCells.map((cell) => cell.id),
      );
      final chainModel = EngineDiscoveryPuzzleViewModel(
        boardConfig: DiscoveryBoardConfig.compactPhone,
      );
      addTearDown(chainModel.dispose);
      _swap(chainModel, DiscoveryTutorialFixture.steps.first);
      final source = chainModel.boardTurnMotion!;
      final cascade = source.cascades.first;
      expect(cascade.discoveries, isNotEmpty);
      final chain = DiscoveryBoardTurnMotion(
        fromIndex: source.fromIndex,
        toIndex: source.toIndex,
        accepted: true,
        beforeSwap: source.beforeSwap,
        afterSwap: source.afterSwap,
        cascades: [
          for (var index = 0; index < 100; index++)
            DiscoveryCascadeMotion(
              index: index,
              clearedIndices: cascade.clearedIndices,
              afterClear: cascade.afterClear,
              afterFall: cascade.afterFall,
              afterRefill: cascade.afterRefill,
              sealHits: cascade.sealHits,
              createdPowers: cascade.createdPowers,
              activatedPowers: cascade.activatedPowers,
              discoveries: cascade.discoveries,
            ),
        ],
      );
      final timeline = discoveryMotionTimeline(
        chain,
        columns: chainModel.boardColumns,
      );
      final phases = timeline.phases;
      expect(
        phases
            .where((phase) => phase.kind == DiscoveryMotionPhaseKind.clear)
            .length,
        100,
      );
      expect(
        phases.fold<int>(
          0,
          (total, phase) => total + phase.duration.inMilliseconds,
        ),
        lessThanOrEqualTo(3000),
      );
      expect(timeline.duration, lessThanOrEqualTo(const Duration(seconds: 3)));
      expect(timeline.discoveries, hasLength(100));
      expect(
        timeline.discoveries.every((window) => window.end <= timeline.duration),
        isTrue,
      );
    },
  );

  testWidgets('no-match exchange visibly returns to the exact original board', (
    tester,
  ) async {
    final probe = _model('r01-c05-s01');
    final pair = _rejectedPair(probe);
    probe.dispose();
    final model = _model('r01-c05-s01');
    addTearDown(model.dispose);
    await _show(tester, model);
    final before = model.exportSession();
    final scoreBefore = model.score;
    final initialIds = model.boardCells.map((cell) => cell.id).toList();
    final sourcePoint = tester.getTopLeft(_gridGems().at(pair.first));
    final destinationPoint = tester.getTopLeft(_gridGems().at(pair.last));
    await tester.tap(_gridGems().at(pair.first));
    await tester.pumpAndSettle();
    await tester.tap(_gridGems().at(pair.last));
    await tester.pump();
    final sprite = find.byKey(ValueKey('motion-gem-${initialIds[pair.first]}'));
    await tester.pump(_timeline(model).phases.first.duration ~/ 2);
    final middle = tester.getTopLeft(sprite);
    expect(middle.dx, greaterThan(sourcePoint.dx));
    expect(middle.dx, lessThan(destinationPoint.dx));
    expect(model.movesLeft, model.stage.moveLimit);
    await tester.pumpAndSettle();
    expect(_lock(tester).busy, isFalse);
    expect(model.boardCells.map((cell) => cell.id), initialIds);
    final after = model.exportSession();
    for (final key in [
      'boardState',
      'acceptedSwaps',
      'discoveredTokenIds',
      'answerTokenIds',
    ]) {
      expect(
        after[key],
        before[key],
        reason: 'Rejected swap must preserve $key.',
      );
    }
    expect(model.score, scoreBefore);
    expect(sprite, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gems travel before clear and tokens arrive before UI unlocks', (
    tester,
  ) async {
    final model = EngineDiscoveryPuzzleViewModel(
      boardConfig: DiscoveryBoardConfig.compactPhone,
    );
    addTearDown(model.dispose);
    await _show(tester, model);
    final sourceId = model.boardCells[1].id;
    final initialTop = tester.getTopLeft(_gridGems().at(1)).dy;
    final destinationTop = tester.getTopLeft(_gridGems().at(6)).dy;
    await _tapTutorialSwap(tester);
    final moving = find.byKey(ValueKey('motion-gem-$sourceId'));
    expect(moving, findsOneWidget);
    expect(_gridGems(), findsNWidgets(25));
    expect(_lock(tester).busy, isTrue);
    expect(model.movesLeft, model.stage.moveLimit - 1);
    expect(
      model.discoveredBlocks.any((block) => block.id == 'p1-times'),
      isTrue,
    );
    expect(_lock(tester).isPending('p1-times'), isTrue);
    expect(
      find.byKey(const ValueKey('discovery-flight-p1-times')),
      findsNothing,
    );
    await tester.pump(_timeline(model).phases.first.duration ~/ 2);
    final middleTop = tester.getTopLeft(moving).dy;
    expect(middleTop, greaterThan(initialTop));
    expect(middleTop, lessThan(destinationTop));
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.lightbulb_outline_rounded),
          )
          .onPressed,
      isNull,
    );
    final answerBefore = model.answerBlocks.length;
    final tokenButtons = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.label == '4 블록, 식에 추가',
    );
    await tester.tap(tokenButtons);
    await tester.pump();
    expect(model.answerBlocks.length, answerBefore);
    await tester.pumpAndSettle();
    expect(_lock(tester).busy, isFalse);
    expect(_lock(tester).isPending('p1-times'), isFalse);
    expect(moving, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset, model replacement and disposal safely cancel playback', (
    tester,
  ) async {
    final model = EngineDiscoveryPuzzleViewModel(
      boardConfig: DiscoveryBoardConfig.compactPhone,
    );
    addTearDown(model.dispose);
    await _show(tester, model);
    await _tapTutorialSwap(tester);
    await tester.tap(find.byTooltip('이 스테이지 처음부터 다시 도전'));
    await tester.pump();
    expect(_lock(tester).busy, isFalse);
    expect(model.movesLeft, model.stage.moveLimit);
    expect(model.boardTurnMotion, isNull);
    await _tapTutorialSwap(tester);
    expect(_lock(tester).busy, isTrue);
    expect(_motionSprites(), findsWidgets);
    final replacement = _model('r01-c05-s01');
    addTearDown(replacement.dispose);
    await _show(tester, replacement, settle: false);
    expect(_lock(tester).busy, isFalse);
    expect(_motionSprites(), findsNothing);
    expect(replacement.movesLeft, replacement.stage.moveLimit);
    await tester.pumpAndSettle();
    _swap(replacement, _path(replacement).first);
    await tester.pump();
    expect(_lock(tester).busy, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'created powers grow before settle without a position or scale jump',
    (tester) async {
      final model = _model('r01-c01-s04');
      addTearDown(model.dispose);
      DiscoveryTutorialStep? powerStep;
      Map<String, dynamic>? checkpoint;
      for (final step in _path(model)) {
        final before = model.exportSession();
        _swap(model, step);
        if (model.boardTurnMotion!.cascades.any(
          (cascade) => cascade.createdPowers.isNotEmpty,
        )) {
          powerStep = step;
          checkpoint = jsonDecode(jsonEncode(before)) as Map<String, dynamic>;
          break;
        }
      }
      expect(powerStep, isNotNull);
      model.restoreSession(checkpoint!);
      await _show(tester, model, textScale: 1.3);
      await _tapStep(tester, model, powerStep!);
      final timeline = _timeline(model);
      final clear = timeline.phases.firstWhere(
        (phase) =>
            phase.kind == DiscoveryMotionPhaseKind.clear &&
            phase.cascade!.createdPowers.isNotEmpty,
      );
      final power = clear.cascade!.createdPowers.first;
      final newGem = clear.after[power.index].gem!;
      final oldGem = clear.before[power.index].gem!;
      expect(newGem.id, isNot(oldGem.id));
      expect(newGem.linePowerKind, power.direction);
      final newSprite = _sprite(newGem.id);
      final oldSprite = _sprite(oldGem.id);
      final birth = find.byKey(ValueKey('power-birth-${newGem.id}'));
      final start = _phaseStart(timeline, clear);
      final duration = clear.duration.inMilliseconds;
      final clock = _PlaybackClock(tester);
      await clock.at(start + (duration * .5).floor() - 1);
      expect(newSprite, findsNothing);
      expect(oldSprite, findsOneWidget);
      await clock.at(start + (duration * .6).round());
      expect(newSprite, findsOneWidget);
      expect(oldSprite, findsOneWidget);
      final growing = tester.widget<Transform>(birth).transform.storage;
      expect(growing[0], greaterThan(0));
      expect(growing[0], lessThan(1));
      expect(growing[5], closeTo(growing[0], .0001));
      await clock.at(start + duration - 1);
      final beforeBoundary = tester.getTopLeft(newSprite);
      final fullSize = tester.widget<Transform>(birth).transform.storage;
      expect(fullSize[0], closeTo(1, .01));
      expect(fullSize[5], closeTo(1, .01));
      await clock.at(start + duration + 1);
      expect(newSprite, findsOneWidget);
      expect(oldSprite, findsNothing);
      expect(birth, findsNothing);
      expect(
        (tester.getTopLeft(newSprite) - beforeBoundary).distance,
        lessThan(1.5),
      );
      final settled = tester.widget<Positioned>(newSprite);
      final transform = (settled.child as Opacity).child as Transform;
      expect(transform.transform.storage[0], closeTo(1, .01));
      expect(transform.transform.storage[5], closeTo(1, .01));
      await tester.pumpAndSettle();
      expect(_lock(tester).busy, isFalse);
      expect(_motionSprites(), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'discovery overlays stay inside the board and reveal tokens on arrival',
    (tester) async {
      final model = EngineDiscoveryPuzzleViewModel(
        boardConfig: DiscoveryBoardConfig.compactPhone,
      );
      addTearDown(model.dispose);
      await _show(tester, model, textScale: 1.3);
      await _tapTutorialSwap(tester);
      final timeline = _timeline(model);
      final window = timeline.discoveries.singleWhere(
        (window) => window.cascade.discoveries.any(
          (discovery) => discovery.block.id == 'p1-times',
        ),
      );
      final clock = _PlaybackClock(tester);
      final flight = _flight('p1-times');
      await clock.at(window.start.inMilliseconds - 1);
      expect(flight, findsNothing);
      expect(_lock(tester).isPending('p1-times'), isTrue);
      for (final progress in [.05, .5, .95]) {
        await clock.at(
          window.start.inMilliseconds +
              (window.duration.inMilliseconds * progress).round(),
        );
        expect(flight, findsOneWidget);
        expect(_lock(tester).busy, isTrue);
        expect(_lock(tester).isPending('p1-times'), isTrue);
        _expectCardInsideBoard(tester, flight);
      }
      await clock.at(window.end.inMilliseconds + 1);
      expect(flight, findsNothing);
      expect(_lock(tester).isPending('p1-times'), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(_lock(tester).busy, isFalse);
    },
  );

  testWidgets(
    'reduced motion skips waits and changing it mid-turn completes instantly',
    (tester) async {
      final model = EngineDiscoveryPuzzleViewModel(
        boardConfig: DiscoveryBoardConfig.compactPhone,
      );
      addTearDown(model.dispose);
      await _show(tester, model, disabled: true);
      await _tapTutorialSwap(tester);
      expect(_lock(tester).busy, isFalse);
      expect(
        find.byKey(const ValueKey('discovery-flight-p1-times')),
        findsNothing,
      );
      expect(
        model.discoveredBlocks.any((block) => block.id == 'p1-times'),
        isTrue,
      );
      model.resetRound();
      await _show(tester, model);
      await _tapTutorialSwap(tester);
      expect(_lock(tester).busy, isTrue);
      expect(_motionSprites(), findsWidgets);
      final saved = jsonEncode(model.exportSession());
      await _show(tester, model, disabled: true, settle: false);
      expect(_lock(tester).busy, isFalse);
      expect(_motionSprites(), findsNothing);
      expect(_lock(tester).isPending('p1-times'), isFalse);
      expect(jsonEncode(model.exportSession()), saved);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('restoring a mounted checkpoint cancels motion without replay', (
    tester,
  ) async {
    final model = EngineDiscoveryPuzzleViewModel(
      boardConfig: DiscoveryBoardConfig.compactPhone,
    );
    addTearDown(model.dispose);
    await _show(tester, model);
    await _tapTutorialSwap(tester);
    final saved =
        jsonDecode(jsonEncode(model.exportSession())) as Map<String, dynamic>;
    expect(_lock(tester).busy, isTrue);
    model.restoreSession(saved);
    await tester.pump();
    expect(model.exportSession(), saved);
    expect(model.boardTurnMotion, isNull);
    expect(_lock(tester).busy, isFalse);
    expect(_motionSprites(), findsNothing);
    expect(_flight('p1-times'), findsNothing);
    expect(_lock(tester).isPending('p1-times'), isFalse);
    await tester.pump(const Duration(seconds: 3));
    expect(_motionSprites(), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final config in [
    DiscoveryBoardConfig.compactPhone,
    DiscoveryBoardConfig.standardPhone,
  ]) {
    final size = config == DiscoveryBoardConfig.compactPhone
        ? const Size(680, 300)
        : const Size(960, 432);
    testWidgets(
      '${config.rows}x${config.columns}: settle is continuous, accelerates and lands exactly',
      (tester) async {
        final model = EngineDiscoveryPuzzleViewModel(boardConfig: config);
        addTearDown(model.dispose);
        // This second tutorial turn removes interior cells, leaving old gems
        // above the holes as well as new refill gems in the same columns.
        _swap(model, DiscoveryTutorialFixture.steps.first);
        await _show(
          tester,
          model,
          size: size,
          textScale: 1.3,
          safePadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        );
        await _tapStep(tester, model, DiscoveryTutorialFixture.steps[1]);
        final timeline = _timeline(model);
        final phase = timeline.phases.firstWhere(
          (phase) => phase.kind == DiscoveryMotionPhaseKind.settle,
        );
        final start = _phaseStart(timeline, phase);
        final duration = phase.duration.inMilliseconds;
        final beforeIndices = <String, int>{
          for (var index = 0; index < phase.before.length; index++)
            if (phase.before[index].gem != null)
              phase.before[index].gem!.id: index,
        };
        final fallingIndices = [
          for (var index = 0; index < phase.after.length; index++)
            if (beforeIndices[phase.after[index].gem!.id] case final before?)
              if (index ~/ model.boardColumns > before ~/ model.boardColumns)
                index,
        ];
        final refillIndices = [
          for (var index = 0; index < phase.after.length; index++)
            if (!beforeIndices.containsKey(phase.after[index].gem!.id)) index,
        ];
        expect(fallingIndices, isNotEmpty);
        expect(refillIndices, isNotEmpty);
        final destinationIndex = fallingIndices.first;
        final oldId = phase.after[destinationIndex].gem!.id;
        final refillIndex = refillIndices.last;
        final newId = phase.after[refillIndex].gem!.id;
        final sourcePoint = tester.getTopLeft(
          _gridGems().at(beforeIndices[oldId]!),
        );
        final destinationPoint = tester.getTopLeft(
          _gridGems().at(destinationIndex),
        );
        final refillDestination = tester.getTopLeft(
          _gridGems().at(refillIndex),
        );
        final stationaryIndex = phase.after.indexWhere(
          (cell) =>
              cell.gem != null &&
              beforeIndices[cell.gem!.id] == phase.after.indexOf(cell),
        );
        expect(stationaryIndex, greaterThanOrEqualTo(0));
        final stationaryId = phase.after[stationaryIndex].gem!.id;
        final stationaryPoint = tester.getTopLeft(
          _gridGems().at(stationaryIndex),
        );
        final clock = _PlaybackClock(tester);
        await clock.at(start - 1);
        final beforeBoundary = tester.getTopLeft(_sprite(oldId));
        await clock.at(start + 1);
        final afterBoundary = tester.getTopLeft(_sprite(oldId));
        expect((afterBoundary - beforeBoundary).distance, lessThan(1.5));
        expect((afterBoundary - sourcePoint).distance, lessThan(1.5));
        final samples = <Offset>[];
        for (final progress in [.15, .25, .35]) {
          await clock.at(start + (duration * progress).round());
          samples.add(tester.getTopLeft(_sprite(oldId)));
          expect(
            (tester.getTopLeft(_sprite(stationaryId)) - stationaryPoint)
                .distance,
            lessThan(.5),
          );
        }
        final firstTravel = samples[1].dy - samples[0].dy;
        final secondTravel = samples[2].dy - samples[1].dy;
        expect(firstTravel, greaterThan(0));
        expect(secondTravel, greaterThan(firstTravel));
        expect(
          samples.every((point) => (point.dx - sourcePoint.dx).abs() < .5),
          isTrue,
        );
        await clock.at(start + (duration * .65).round());
        expect(_sprite(oldId), findsOneWidget);
        expect(_sprite(newId), findsOneWidget);
        final survivorPoint = tester.getTopLeft(_sprite(oldId));
        final refillPoint = tester.getTopLeft(_sprite(newId));
        expect(survivorPoint.dy, greaterThan(sourcePoint.dy));
        expect(survivorPoint.dy, lessThan(destinationPoint.dy));
        expect(refillPoint.dy, lessThan(refillDestination.dy));
        final board = tester.getRect(find.byType(DiscoveryAnimatedGemBoard));
        expect(board.contains(tester.getRect(_sprite(newId)).center), isTrue);
        await clock.at(start + duration - 1);
        expect(
          (tester.getTopLeft(_sprite(oldId)) - destinationPoint).distance,
          lessThan(.75),
        );
        expect(
          (tester.getTopLeft(_sprite(newId)) - refillDestination).distance,
          lessThan(.75),
        );
        await tester.pumpAndSettle();
        expect(_lock(tester).busy, isFalse);
        expect(_motionSprites(), findsNothing);
        expect(_gridGems(), findsNWidgets(config.rows * config.columns));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${config.rows}x${config.columns}: multiple cascades preserve the exact final board',
      (tester) async {
        final model = _twoCascadeModel(config);
        addTearDown(model.dispose);
        await _show(
          tester,
          model,
          size: size,
          textScale: 1.3,
          safePadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        );
        await _tapTutorialSwap(tester);
        final trace = model.boardTurnMotion!;
        final timeline = _timeline(model);
        expect(trace.cascades, hasLength(2));
        final settles = timeline.phases
            .where((phase) => phase.kind == DiscoveryMotionPhaseKind.settle)
            .toList();
        expect(settles, hasLength(trace.cascades.length));
        for (var index = 0; index < settles.length; index++) {
          expect(settles[index].before, trace.cascades[index].afterClear);
          expect(settles[index].after, trace.cascades[index].afterRefill);
        }
        expect(
          settles.last.after.map((cell) => cell.gem!.id),
          model.boardCells.map((cell) => cell.id),
        );
        final expected = jsonEncode(model.exportSession());
        final clock = _PlaybackClock(tester);
        for (final phase in settles) {
          await clock.at(
            _phaseStart(timeline, phase) + phase.duration.inMilliseconds - 1,
          );
          expect(_motionSprites(), findsNWidgets(config.rows * config.columns));
          expect(tester.takeException(), isNull);
        }
        await tester.pumpAndSettle();
        expect(jsonEncode(model.exportSession()), expected);
        expect(_gridGems(), findsNWidgets(config.rows * config.columns));
        expect(_motionSprites(), findsNothing);
        expect(_lock(tester).busy, isFalse);
        expect(_lock(tester).isPending('p1-times'), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('6x6 layout, legacy model and rapid engine turns converge', (
    tester,
  ) async {
    final model = EngineDiscoveryPuzzleViewModel(
      boardConfig: DiscoveryBoardConfig.standardPhone,
    );
    addTearDown(model.dispose);
    await _show(tester, model, size: const Size(960, 432));
    expect(_gridGems(), findsNWidgets(36));
    for (final step in DiscoveryTutorialFixture.steps) _swap(model, step);
    await tester.pumpAndSettle();
    expect(_lock(tester).busy, isFalse);
    expect(model.discoveredBlocks.map((block) => block.id).toSet().length, 5);
    final legacy = DemoDiscoveryPuzzleViewModel();
    addTearDown(legacy.dispose);
    await _show(tester, legacy, size: const Size(960, 432));
    await tester.tap(_gridGems().at(0));
    await tester.pumpAndSettle();
    await tester.tap(_gridGems().at(1));
    await tester.pumpAndSettle();
    expect(_lock(tester).busy, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact board preserves all cells with enlarged text and safe padding',
    (tester) async {
      final model = EngineDiscoveryPuzzleViewModel(
        boardConfig: DiscoveryBoardConfig.compactPhone,
      );
      addTearDown(model.dispose);
      await _show(
        tester,
        model,
        size: const Size(680, 300),
        textScale: 1.3,
        safePadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      );
      expect(model.boardRows, 5);
      expect(model.boardColumns, 5);
      expect(_gridGems(), findsNWidgets(25));
      final boardRect = tester.getRect(find.byType(GridView));
      expect(boardRect.left, greaterThanOrEqualTo(24));
      expect(boardRect.right, lessThanOrEqualTo(656));
      expect(boardRect.bottom, lessThanOrEqualTo(288));
      for (var index = 0; index < 25; index++) {
        final cellRect = tester.getRect(_gridGems().at(index));
        expect(cellRect.width, greaterThan(0));
        expect(boardRect.contains(cellRect.center), isTrue);
      }
      expect(tester.takeException(), isNull);
      await _tapTutorialSwap(tester);
      await tester.pump(const Duration(milliseconds: 95));
      expect(_motionSprites(), findsNWidgets(25));
      expect(_gridGems(), findsNWidgets(25));
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(_lock(tester).busy, isFalse);
      expect(_gridGems(), findsNWidgets(25));
      expect(tester.takeException(), isNull);
    },
  );
}
