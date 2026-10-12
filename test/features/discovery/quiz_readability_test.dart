import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/core/theme/app_theme.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/discovery/domain/discovery_models.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_screen.dart';
import 'package:kvm/features/discovery/presentation/engine_discovery_puzzle_view_model.dart';

void main() {
  for (final size in [
    const Size(680, 300),
    const Size(640, 288),
    const Size(568, 320),
    const Size(480, 270),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('quiz and seven-token workspace fit $size at $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final model = EngineDiscoveryPuzzleViewModel(
          stage: initialCampaign.stageById('r01-c03-s02')!,
          boardConfig: DiscoveryBoardConfig.compactPhone,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              ),
              child: child!,
            ),
            home: DiscoveryPuzzleScreen(viewModel: model),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(model.boardCells, hasLength(25));
        for (final finder in [
          find.byKey(const ValueKey('puzzle-question-panel')),
          find.byKey(const ValueKey('puzzle-equation-workspace')),
          find.byKey(const ValueKey('question-reader-button')),
          find.byTooltip('힌트 보기'),
          find.text('확인'),
        ]) {
          expect(finder, findsOneWidget);
          final rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
        }
        final questionText = tester.widget<Text>(
          find.byKey(const ValueKey('puzzle-question-text')),
        );
        final span = questionText.textSpan! as TextSpan;
        expect(span.style!.fontSize, greaterThanOrEqualTo(14.5));
        expect(questionText.maxLines, isNull);
        expect(span.toPlainText(), model.question);

        // Reading help must not consume a move, reveal a math hint, clear the
        // pending equation, or change the deterministic board checkpoint.
        model.addBlockToAnswer(model.discoveredBlocks.first.id);
        await tester.pumpAndSettle();
        final checkpoint = model.exportSession();
        await tester.tap(find.byKey(const ValueKey('question-reader-button')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(model.sentenceMath!.targetQuestion),
          ),
          findsOneWidget,
        );
        expect(find.text('알고 있는 조건'), findsOneWidget);
        expect(find.text('구할 것'), findsOneWidget);
        for (final fact in model.sentenceMath!.givenFacts) {
          expect(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text(fact),
            ),
            findsOneWidget,
          );
        }
        expect(
          find.text(model.sentenceMath!.relationshipExplanation),
          findsNothing,
        );
        expect(model.exportSession(), checkpoint);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('퍼즐로 돌아가기'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(model.exportSession(), checkpoint);
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
      });
    }
  }

  for (final scale in [1.0, 1.3]) {
    testWidgets('all R1/R2 questions fit reading pane at 680x300 / $scale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(680, 300);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final stage
          in initialCampaign.regions.take(2).expand((r) => r.stages)) {
        final model = EngineDiscoveryPuzzleViewModel(
          stage: stage,
          boardConfig: DiscoveryBoardConfig.compactPhone,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
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
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byKey(const ValueKey('puzzle-question-text')),
            matching: find.byType(RichText),
          ),
        );
        final viewport = tester.getSize(
          find.byKey(const ValueKey('puzzle-question-scroll')),
        );
        expect(
          paragraph.size.height,
          lessThanOrEqualTo(viewport.height + 0.5),
          reason: '${stage.id}: normal viewport must not need question scroll',
        );
        expect(tester.takeException(), isNull, reason: stage.id);
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
      }
    });
  }
}
