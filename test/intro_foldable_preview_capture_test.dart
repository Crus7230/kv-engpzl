import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/app/math_adventure_app.dart';
import 'package:kvm/core/branding/adventure_intro_screen.dart';
import 'package:kvm/core/layout/landscape_game_viewport.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_screen.dart';
import 'package:kvm/features/exploration/presentation/r1_expedition_screen.dart';
import 'package:kvm/features/garden/data/garden_catalog.dart';
import 'package:kvm/features/garden/presentation/adventure_collection_screens.dart';
import 'package:kvm/features/garden/presentation/garden_screens.dart';
import 'package:kvm/features/progress/progress.dart';

// Full-app Flutter renders at simulated phone/foldable sizes, not device
// screenshots or approved golden baselines. No production save is touched.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final font = File(r'C:\Windows\Fonts\malgun.ttf');
    if (await font.exists()) {
      final bytes = ByteData.sublistView(await font.readAsBytes());
      for (final family in ['Roboto', 'Malgun Gothic']) {
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
    Size(680, 300),
    Size(900, 700),
    Size(1280, 800),
    Size(960, 960),
  ]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('full app $size text $scale keeps its landscape frame', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final boundaryKey = GlobalKey();
        final chapter = initialCampaign.regions.first.chapters.first;
        final nodes = gardenDefinitions.first.restorationNodes
            .where((node) => node.chapterId == chapter.id)
            .toList();
        final fixture = SaveEnvelopeV1.initial().copyWith(
          playerCharacterId: 'CHAR_D',
          starterCharacterId: 'CHAR_D',
          onboardingCompleted: true,
          unlockedCharacterIds: const ['CHAR_D', 'CHAR_J'],
          viewedStoryIds: const [
            'expedition-join-CHAR_D',
            'expedition-join-CHAR_J',
          ],
          completedStageIds: chapter.stages.map((stage) => stage.id),
          unlockedStageIds: [
            ...chapter.stages.map((stage) => stage.id),
            'r01-c02-s01',
          ],
          bestStars: {for (final stage in chapter.stages) stage.id: 1},
          dailyReviewActions: const {
            '2026-10-07': 1,
            '2026-10-08': 1,
            '2026-10-09': 1,
            '2026-10-11': 1,
            '2026-10-12': 1,
          },
          dailyActions: const {
            '2026-10-07': 2,
            '2026-10-08': 2,
            '2026-10-09': 2,
            '2026-10-11': 2,
            '2026-10-12': 2,
          },
          restoredNodeIds: nodes.take(2).map((node) => node.id),
          rewardLedger: {
            for (final node in nodes)
              'capture-${node.id}': CompletionReceipt(
                attemptId: 'capture-${node.id}',
                stageId: node.requiredStageId,
                stars: 1,
                firstCompletion: true,
                supportReviewNeeded: false,
                unlockedRestorationNodeIds: [node.id],
              ),
          },
        );
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MathAdventureApp(
              repository: ProgressRepository(
                MemoryKeyValueSaveStore(),
                initialFactory: () => fixture,
              ),
              assetBundle: rootBundle,
              now: () => DateTime(2026, 10, 13),
            ),
          ),
        );

        Future<void> capture(
          String state, {
          String? motionName,
          int? motionFrame,
        }) async {
          await tester.runAsync(() async {
            for (final widget in tester.widgetList<Image>(find.byType(Image))) {
              await precacheImage(widget.image, boundaryKey.currentContext!);
            }
          });
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$state $size $scale');
          final frame = tester.getRect(
            find.byKey(LandscapeGameViewport.frameKey),
          );
          expect(frame.size, LandscapeGameViewport.fit(size));
          expect(frame.center, Offset(size.width / 2, size.height / 2));
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final directory = Directory(
                motionName == null
                    ? 'build/previews/intro-foldable'
                    : 'build/previews/motion-$motionName',
              );
              await directory.create(recursive: true);
              final filename = motionFrame == null
                  ? '${state}_${size.width.toInt()}x${size.height.toInt()}_text${(scale * 100).round()}_flutter-simulated.png'
                  : 'frame-${motionFrame.toString().padLeft(3, '0')}.png';
              await File(
                '${directory.path}/$filename',
              ).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
            } finally {
              image.dispose();
            }
          });
        }

        Future<void> captureEntrance(String name) async {
          if (size != const Size(800, 360) || scale != 1) return;
          const frames = 13;
          const milliseconds = 150;
          for (var frame = 0; frame < frames; frame++) {
            if (frame > 0) {
              await tester.pump(const Duration(milliseconds: milliseconds));
            }
            await capture(name, motionName: name, motionFrame: frame);
          }
          await tester.runAsync(() async {
            await File(
              'build/previews/motion-$name/capture.json',
            ).writeAsString(
              jsonEncode({
                'frames': frames,
                'frameMilliseconds': milliseconds,
                'turnMilliseconds': (frames - 1) * milliseconds,
                'simulated': true,
              }),
              flush: true,
            );
          });
        }

        await tester.pump();
        // Capture the completed legacy-style sequence before the 2.4s gate.
        await tester.pump(const Duration(milliseconds: 400));
        if (size == const Size(800, 360) && scale == 1) {
          await capture('intro-0400ms');
        }
        await tester.pump(const Duration(milliseconds: 600));
        if (size == const Size(800, 360) && scale == 1) {
          await capture('intro-1000ms');
        }
        await tester.pump(const Duration(milliseconds: 800));
        if (size == const Size(800, 360) && scale == 1) {
          await capture('intro-1800ms');
        }
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(AdventureIntroScreen), findsOneWidget);
        await capture('intro');
        await tester.pumpAndSettle();
        await capture('world-map');

        tester.widget<WorldMapScreen>(find.byType(WorldMapScreen)).onReview!();
        await tester.pump();
        await captureEntrance('memory-seeds-entry');
        await tester.pumpAndSettle();
        await capture('memory-seeds');
        tester
            .widget<MemorySeedsScreen>(find.byType(MemorySeedsScreen))
            .onBack();
        await tester.pumpAndSettle();
        tester.widget<WorldMapScreen>(find.byType(WorldMapScreen)).onTraces!();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('passport-${chapter.id}')));
        await tester.pump();
        await captureEntrance('passport-stamp-entry');
        await tester.pumpAndSettle();
        await capture('expedition-traces');
        tester
            .widget<ExpeditionTracesScreen>(find.byType(ExpeditionTracesScreen))
            .onBack();
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('world-region-region-01-calculation')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(R1ExpeditionScreen), findsOneWidget);
        await capture('r1-map');

        await tester.tap(find.byKey(const ValueKey('expedition-play')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('탐험 시작하기'));
        await tester.pumpAndSettle();
        expect(find.byType(DiscoveryPuzzleScreen), findsOneWidget);
        await capture('puzzle');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
