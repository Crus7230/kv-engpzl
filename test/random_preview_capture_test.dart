import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/core/theme/app_theme.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/campaign/data/r1_authored_campaign.dart';
import 'package:kvm/features/discovery/data/discovery_challenge_profile.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_screen.dart';
import 'package:kvm/features/discovery/presentation/engine_discovery_puzzle_view_model.dart';

// Real-widget raster captures, not Android device screenshots. The diagnostic
// route drives fixed regression states only; production never auto-plays it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = File(
      Platform.environment['KVM_PREVIEW_FONT'] ??
          r'C:\Windows\Fonts\malgun.ttf',
    );
    if (await font.exists()) {
      final bytes = ByteData.sublistView(await font.readAsBytes());
      for (final family in ['KvmPreviewKorean', 'Roboto', 'Segoe UI']) {
        await (FontLoader(family)..addFont(Future.value(bytes))).load();
      }
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final size in const [Size(800, 360), Size(680, 300)]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('capture v5 gates $size text $scale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final key = GlobalKey();
        final theme = AppTheme.light();
        final earlyStage = initialCampaign.stageById('r01-c01-s02')!;
        final advancedStage = initialCampaign.stageById('r02-c06-s10')!;
        final early = EngineDiscoveryPuzzleViewModel(
          stage: earlyStage,
          rulesVersion: 5,
          boardSeed: 42,
          boardConfig: DiscoveryChallengeProfile.boardFor(
            earlyStage,
            size.width,
            size.height,
          ),
        );
        final advanced = EngineDiscoveryPuzzleViewModel(
          stage: advancedStage,
          rulesVersion: 5,
          boardSeed: 42,
          boardConfig: DiscoveryChallengeProfile.boardFor(
            advancedStage,
            size.width,
            size.height,
          ),
        );
        addTearDown(early.dispose);
        addTearDown(advanced.dispose);
        Future<void> capture(
          String state,
          EngineDiscoveryPuzzleViewModel model,
        ) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme.copyWith(
                textTheme: theme.textTheme.apply(
                  fontFamily: 'KvmPreviewKorean',
                ),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: RepaintBoundary(key: key, child: child!),
              ),
              home: DiscoveryPuzzleScreen(
                key: ValueKey(model.stage.id),
                viewModel: model,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$state $size $scale');
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final rendered = await boundary.toImage(pixelRatio: 1);
            final bytes = await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            );
            rendered.dispose();
            final dir = Directory('build/previews/random-v5');
            await dir.create(recursive: true);
            await File(
              '${dir.path}/${state}_${size.width.toInt()}x${size.height.toInt()}_text${(scale * 100).round()}_flutter-simulated.png',
            ).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
          });
        }

        await capture('r1-random-start', early);
        early.revealHint();
        expect(early.isHintVisible, isTrue);
        await capture('r1-hint-open', early);
        early.hideHint();
        expect(early.isHintVisible, isFalse);
        await capture('r1-hint-closed', early);
        for (final step in early.referencePath) {
          early.selectGem(
            step.from.row * early.boardColumns + step.from.column,
          );
          early.selectGem(step.to.row * early.boardColumns + step.to.column);
        }
        expect(early.discoveryObjectives.every((g) => g.isCompleted), isTrue);
        for (final token in authoredPuzzlesByStageId[early.stage.id]!.tokens) {
          early.addBlockToAnswer(token.id);
        }
        expect(early.canCheckAnswer, isTrue);
        await capture('r1-both-gates-ready', early);
        early.checkAnswer();
        expect(early.isAnswerCorrect, isTrue);
        await capture('r1-answer-correct', early);
        await capture('r2-dense-ice-drop-start', advanced);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
