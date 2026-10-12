import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/discovery/data/discovery_challenge_profile.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_screen.dart';
import 'package:kvm/features/discovery/presentation/engine_discovery_puzzle_view_model.dart';

void main() {
  final cases = [
    (id: 'r01-c01-s02', size: const Size(680, 300), side: 6),
    (id: 'r01-c01-s02', size: const Size(800, 360), side: 6),
    (id: 'r02-c06-s10', size: const Size(800, 360), side: 7),
    (id: 'r02-c06-s10', size: const Size(720, 320), side: 7),
    (id: 'r02-c06-s10', size: const Size(680, 300), side: 6),
    (id: 'r01-c01-s02', size: const Size(480, 270), side: 5),
  ];
  for (final sample in cases) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('density ${sample.side} fits ${sample.size} text $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = sample.size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final semantics = tester.ensureSemantics();
        try {
          final stage = initialCampaign.stageById(sample.id)!;
          final config = DiscoveryChallengeProfile.boardFor(
            stage,
            sample.size.width,
            sample.size.height,
          );
          final model = EngineDiscoveryPuzzleViewModel(
            stage: stage,
            rulesVersion: 5,
            boardSeed: 42,
            boardConfig: config,
          );
          addTearDown(model.dispose);
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: DiscoveryPuzzleScreen(viewModel: model),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(model.boardCells, hasLength(sample.side * sample.side));
          expect(find.text('발굴 ${sample.side}×${sample.side}'), findsOneWidget);
          final gridFinder = find.byKey(const ValueKey('discovery-gem-grid'));
          final grid = tester.widget<GridView>(gridFinder);
          expect(
            grid.childrenDelegate.estimatedChildCount,
            sample.side * sample.side,
          );
          final lastCell = find.bySemanticsLabel(
            RegExp('^${sample.side}행 ${sample.side}열,'),
          );
          expect(lastCell, findsOneWidget);
          final cellRect = tester.getRect(lastCell);
          final gridRect = tester.getRect(gridFinder);
          expect(cellRect.left, greaterThanOrEqualTo(gridRect.left));
          expect(cellRect.top, greaterThanOrEqualTo(gridRect.top));
          expect(cellRect.right, lessThanOrEqualTo(gridRect.right + .01));
          expect(cellRect.bottom, lessThanOrEqualTo(gridRect.bottom + .01));
          expect(cellRect.shortestSide, greaterThan(0));
          final step = model.referencePath.first;
          await tester.tap(
            find.bySemanticsLabel(
              RegExp('^${step.from.row + 1}행 ${step.from.column + 1}열,'),
            ),
          );
          await tester.tap(
            find.bySemanticsLabel(
              RegExp('^${step.to.row + 1}행 ${step.to.column + 1}열,'),
            ),
          );
          await tester.pumpAndSettle();
          expect(model.exportSession()['acceptedSwaps'], hasLength(1));
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
  }
}
