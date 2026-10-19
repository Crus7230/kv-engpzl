import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/core/theme/app_theme.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/discovery/domain/discovery_models.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_screen.dart';
import 'package:kvm/features/discovery/presentation/engine_discovery_puzzle_view_model.dart';

import '../../support/compact_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCompactPreviewFonts);
  final measurements = <Map<String, Object>>[];
  tearDownAll(() async {
    final file = File('build/previews/compact-seeker/focused-metrics.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(measurements),
    );
  });
  for (final size in [
    const Size(568, 256),
    const Size(640, 280),
    const Size(680, 300),
  ]) {
    for (final config in [
      DiscoveryBoardConfig.compactPhone,
      DiscoveryBoardConfig.standardPhone,
      DiscoveryBoardConfig.densePhone,
    ]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          'board-focused ${config.rows}x${config.columns} at $size text $scale',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPhysicalSize);
            final semantics = tester.ensureSemantics();
            try {
              final model = EngineDiscoveryPuzzleViewModel(
                stage: initialCampaign.stageById(
                  config.rows == 6 ? 'r02-c06-s10' : 'r01-c04-s06',
                )!,
                rulesVersion: 6,
                boardSeed: 42,
                boardConfig: config,
              );
              addTearDown(model.dispose);
              await tester.pumpWidget(
                RepaintBoundary(
                  key: const Key('compact-puzzle-capture'),
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.light(),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: DiscoveryPuzzleScreen(viewModel: model),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              final bounds = Offset.zero & size;
              for (final key in [
                'puzzle-question-panel',
                'discovery-gem-grid',
                'puzzle-equation-workspace',
                'seeker-guide',
                'puzzle-submit',
                'puzzle-objectives',
              ]) {
                final rect = tester.getRect(find.byKey(ValueKey(key)));
                expect(bounds.intersect(rect), rect);
              }
              final grid = tester.widget<GridView>(
                find.byKey(const ValueKey('discovery-gem-grid')),
              );
              expect(
                grid.childrenDelegate.estimatedChildCount,
                config.rows * config.columns,
              );
              final gridRect = tester.getRect(
                find.byKey(const ValueKey('discovery-gem-grid')),
              );
              final questionRect = tester.getRect(
                find.byKey(const ValueKey('puzzle-question-panel')),
              );
              final workspaceRect = tester.getRect(
                find.byKey(const ValueKey('puzzle-equation-workspace')),
              );
              expect(gridRect.height, greaterThanOrEqualTo(size.height - 66));
              expect(gridRect.width, greaterThan(questionRect.width));
              expect(gridRect.width, greaterThan(workspaceRect.width));
              expect(
                tester
                    .getRect(find.byKey(const ValueKey('puzzle-objectives')))
                    .bottom,
                lessThanOrEqualTo(gridRect.top),
              );
              for (
                var index = 0;
                index < model.discoveryObjectives.length;
                index++
              ) {
                final rect = tester.getRect(
                  find.byKey(ValueKey('puzzle-objective-$index')),
                );
                expect(bounds.intersect(rect), rect);
                expect(rect.shortestSide, greaterThanOrEqualTo(44));
              }
              final lastCell = find.bySemanticsLabel(
                RegExp('^${config.rows}행 ${config.columns}열,'),
              );
              final cellRect = tester.getRect(lastCell);
              expect(
                cellRect.shortestSide,
                greaterThanOrEqualTo(
                  (size.height - 66 - config.rows + 1) / config.rows,
                ),
              );
              final text = tester.widget<Text>(
                find.byKey(const ValueKey('puzzle-question-text')),
              );
              final span = text.textSpan! as TextSpan;
              expect(span.style!.fontSize, inInclusiveRange(11, 13.5));
              expect(span.toPlainText(), model.question);
              measurements.add({
                'width': size.width,
                'height': size.height,
                'textScale': scale,
                'rows': config.rows,
                'gridExtent': gridRect.width,
                'cellExtent': cellRect.width,
                'questionWidth': questionRect.width,
                'workspaceWidth': workspaceRect.width,
                'questionFontSize': span.style!.fontSize!,
                'scaledQuestionFontSize': span.style!.fontSize! * scale,
              });
              expect(
                tester
                    .getSize(find.byKey(const Key('seeker-guide')))
                    .shortestSide,
                greaterThanOrEqualTo(44),
              );
              expect(
                tester
                    .getSize(find.byKey(const Key('puzzle-submit')))
                    .shortestSide,
                greaterThanOrEqualTo(44),
              );
              expect(find.byTooltip('식 확인'), findsOneWidget);
              await captureCompactPreview(
                tester,
                const Key('compact-puzzle-capture'),
                'focused-puzzle-${config.rows}-${size.width.toInt()}-${(scale * 100).round()}',
              );
              final checkpoint = model.exportSession();
              await tester.tap(
                find.byKey(const ValueKey('puzzle-objective-0')),
              );
              await tester.pumpAndSettle();
              expect(
                find.byKey(const ValueKey('puzzle-objective-details')),
                findsOneWidget,
              );
              for (final goal in model.discoveryObjectives) {
                expect(find.text(goal.label), findsOneWidget);
              }
              await tester.tap(find.text('닫기'));
              await tester.pumpAndSettle();
              expect(model.exportSession(), checkpoint);
              await tester.tap(find.byKey(const Key('seeker-guide')));
              await tester.pumpAndSettle();
              expect(find.text('2×2 유도탄'), findsOneWidget);
              await tester.tap(find.text('닫기'));
              await tester.pumpAndSettle();
              expect(model.attemptMetrics.highestMathHintTierUsed, 0);
              final move = model.referencePath.first;
              await tester.tap(
                find.bySemanticsLabel(
                  RegExp('^${move.from.row + 1}행 ${move.from.column + 1}열,'),
                ),
              );
              await tester.tap(
                find.bySemanticsLabel(
                  RegExp('^${move.to.row + 1}행 ${move.to.column + 1}열,'),
                ),
              );
              await tester.pumpAndSettle();
              expect(model.exportSession()['acceptedSwaps'], hasLength(1));
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }
}
