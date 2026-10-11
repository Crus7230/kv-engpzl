import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/core/branding/garden_branding.dart';
import 'package:kvm/core/theme/app_theme.dart';
import 'package:kvm/features/discovery/data/tutorial_discovery_fixture.dart';
import 'package:kvm/features/discovery/domain/discovery_models.dart';
import 'package:kvm/features/discovery/presentation/discovery_board_motion.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_screen.dart';
import 'package:kvm/features/discovery/presentation/engine_discovery_puzzle_view_model.dart';
import 'package:kvm/features/garden/presentation/garden_screens.dart';

// These are Flutter-rendered simulated viewports, not Android device captures.
// Captures are generated artifacts, never approved golden baselines.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final path =
        Platform.environment['KVM_PREVIEW_FONT'] ??
        r'C:\Windows\Fonts\malgun.ttf';
    final font = File(path);
    if (await font.exists()) {
      final bytes = ByteData.sublistView(await font.readAsBytes());
      for (final family in ['KvmPreviewKorean', 'Roboto', 'Segoe UI']) {
        final loader = FontLoader(family);
        loader.addFont(Future.value(bytes));
        await loader.load();
      }
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final size in const [
    Size(800, 360),
    Size(720, 320),
    Size(680, 300),
    Size(960, 432),
  ]) {
    testWidgets(
      'capture Flutter simulated ${size.width.toInt()}x${size.height.toInt()} at 100%/130%',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final directory = Directory('build/previews');
        await tester.runAsync(() => directory.create(recursive: true));
        final model = EngineDiscoveryPuzzleViewModel(
          boardConfig: size.width < 720 || size.height < 400
              ? DiscoveryBoardConfig.compactPhone
              : DiscoveryBoardConfig.standardPhone,
        );
        addTearDown(model.dispose);

        for (final scale in [1.0, 1.3]) {
          Future<void> capture(
            String state,
            Widget screen, {
            VoidCallback? play,
            Duration Function()? frameDelay,
          }) async {
            final boundaryKey = GlobalKey();
            final theme = AppTheme.light();
            await tester.pumpWidget(
              MaterialApp(
                theme: theme.copyWith(
                  textTheme: theme.textTheme.apply(
                    fontFamily: 'KvmPreviewKorean',
                  ),
                  primaryTextTheme: theme.primaryTextTheme.apply(
                    fontFamily: 'KvmPreviewKorean',
                  ),
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: RepaintBoundary(key: boundaryKey, child: child!),
                ),
                home: screen,
              ),
            );
            await tester.runAsync(() async {
              for (final widget in tester.widgetList<Image>(
                find.byType(Image),
              )) {
                await precacheImage(widget.image, boundaryKey.currentContext!);
              }
            });
            await tester.pumpAndSettle();
            if (play != null) {
              play();
              await tester.pump();
              await tester.pump(frameDelay?.call() ?? Duration.zero);
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '$state at $size scale $scale',
            );
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final rendered = await boundary.toImage(pixelRatio: 2);
              final bytes = await rendered.toByteData(
                format: ui.ImageByteFormat.png,
              );
              rendered.dispose();
              expect(bytes, isNotNull);
              final file = File(
                '${directory.path}/${state}_${size.width.toInt()}x${size.height.toInt()}_text${(scale * 100).round()}_flutter-simulated.png',
              );
              await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
            });
          }

          await capture(
            'garden-loading',
            const GardenLoadingScreen(status: '지난 탐험 기록을 불러오고 있어요'),
          );
          await capture(
            'world-map',
            WorldMapScreen(
              unlockedRegionIds: const {'region-01-calculation'},
              restoredNodeIds: const {},
              totalStars: 0,
              weeklyActions: 0,
              onExplore: () {},
              onSelectRegion: (_) {},
              onSettings: () {},
            ),
          );
          await capture(
            'garden-before',
            RegionGardenScreen(
              regionId: 'region-01-calculation',
              restoredNodeIds: const {},
              decorationChoices: const {},
              onBack: () {},
              onPlay: () {},
              onRestore: () {},
              canRestore: false,
              hasActiveSession: false,
              demoCompleted: false,
            ),
          );
          await capture(
            'briefing',
            StageBriefingScreen(onBack: () {}, onStart: () {}, resume: false),
          );
          model.resetRound();
          await capture(
            'puzzle-start',
            DiscoveryPuzzleScreen(viewModel: model),
          );
          final first = DiscoveryTutorialFixture.steps.first;
          for (final frame in [
            'swap',
            'seal-hit',
            'fall',
            'refill',
            'discovery',
          ]) {
            await capture(
              'puzzle-motion-$frame',
              DiscoveryPuzzleScreen(viewModel: model),
              play: () {
                model.resetRound();
                model.selectGem(
                  first.from.row * model.boardColumns + first.from.column,
                );
                model.selectGem(
                  first.to.row * model.boardColumns + first.to.column,
                );
              },
              frameDelay: () {
                final timeline = discoveryMotionTimeline(
                  model.boardTurnMotion!,
                  columns: model.boardColumns,
                );
                if (frame == 'discovery') {
                  final window = timeline.discoveries.first;
                  return window.start + window.duration ~/ 2;
                }
                final kind = switch (frame) {
                  'swap' => DiscoveryMotionPhaseKind.swap,
                  'seal-hit' => DiscoveryMotionPhaseKind.clear,
                  _ => DiscoveryMotionPhaseKind.settle,
                };
                var elapsed = Duration.zero;
                for (final phase in timeline.phases) {
                  if (phase.kind == kind) {
                    final fraction = frame == 'refill' ? .7 : .35;
                    return elapsed +
                        Duration(
                          milliseconds:
                              (phase.duration.inMilliseconds * fraction)
                                  .round(),
                        );
                  }
                  elapsed += phase.duration;
                }
                throw StateError('Missing $kind preview phase.');
              },
            );
          }
          model.resetRound();
          model.selectGem(
            first.from.row * model.boardColumns + first.from.column,
          );
          model.selectGem(first.to.row * model.boardColumns + first.to.column);
          model.addBlockToAnswer('p1-n4');
          await capture(
            'puzzle-middle',
            DiscoveryPuzzleScreen(viewModel: model),
          );
          for (final step in DiscoveryTutorialFixture.steps.skip(1)) {
            model.selectGem(
              step.from.row * model.boardColumns + step.from.column,
            );
            model.selectGem(step.to.row * model.boardColumns + step.to.column);
          }
          model.removeBlockFromAnswer('p1-n4');
          for (final id in ['p1-n4', 'p1-plus', 'p1-n3', 'p1-times', 'p1-n2']) {
            model.addBlockToAnswer(id);
          }
          model.checkAnswer();
          expect(model.isAnswerCorrect, isFalse);
          await capture(
            'puzzle-incorrect',
            DiscoveryPuzzleScreen(viewModel: model),
          );
          for (final block in model.answerBlocks.toList()) {
            model.removeBlockFromAnswer(block.id);
          }
          model.revealHint();
          model.revealHint();
          await capture('puzzle-hint', DiscoveryPuzzleScreen(viewModel: model));
          for (final id in ['p1-n4', 'p1-times', 'p1-n3', 'p1-plus', 'p1-n2']) {
            model.addBlockToAnswer(id);
          }
          model.checkAnswer();
          expect(model.isAnswerCorrect, isTrue);
          await capture(
            'puzzle-correct',
            DiscoveryPuzzleScreen(viewModel: model),
          );
          await capture(
            'result',
            StageResultScreen(
              stars: 2,
              firstCompletion: true,
              onContinue: () {},
              onBack: () {},
            ),
          );
          await capture(
            'restoration',
            RestorationRevealScreen(
              alreadyRestored: false,
              decorationId: 'wildflowers',
              onChooseDecoration: (_) {},
              onFinish: () {},
            ),
          );
          await capture(
            'garden-after',
            RegionGardenScreen(
              regionId: 'region-01-calculation',
              restoredNodeIds: const {'r01-demo-meadow'},
              decorationChoices: const {'r01-demo-meadow': 'wildflowers'},
              onBack: () {},
              onPlay: () {},
              onRestore: () {},
              canRestore: true,
              hasActiveSession: false,
              demoCompleted: true,
            ),
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
