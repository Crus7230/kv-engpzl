import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/core/theme/app_theme.dart';
import 'package:kvm/features/companions/data/companion_catalog.dart';
import 'package:kvm/features/companions/presentation/companion_screens.dart';
import 'package:kvm/features/onboarding/presentation/expedition_onboarding_screen.dart';
import 'package:kvm/features/progress/domain/progress_models.dart';

// These are real Flutter raster captures at simulated landscape viewports,
// not screenshots from a physical Android device or approved golden baselines.
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
        final loader = FontLoader(family);
        loader.addFont(Future.value(bytes));
        await loader.load();
      }
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final viewport in const [
    (size: Size(800, 360), scale: 1.0),
    (size: Size(680, 300), scale: 1.3),
  ]) {
    testWidgets(
      'capture expedition onboarding and companions ${viewport.size} ${viewport.scale}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewport.size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        Future<void> capture(String state, Widget screen) async {
          final key = GlobalKey();
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
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(viewport.scale),
                  disableAnimations: true,
                ),
                child: RepaintBoundary(key: key, child: child!),
              ),
              home: screen,
            ),
          );
          await tester.runAsync(() async {
            for (final image in tester.widgetList<Image>(find.byType(Image))) {
              await precacheImage(image.image, key.currentContext!);
            }
          });
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$state at ${viewport.size} text scale ${viewport.scale}',
          );
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            image.dispose();
            final directory = Directory('build/previews');
            await directory.create(recursive: true);
            await File(
              '${directory.path}/expedition_${state}_${viewport.size.width.toInt()}x${viewport.size.height.toInt()}_text${(viewport.scale * 100).round()}_flutter-simulated.png',
            ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
          });
        }

        Widget onboarding(SaveEnvelopeV1 save) => ExpeditionOnboardingScreen(
          save: save,
          onChoosePlayer: (_) {},
          onStartTutorial: () {},
          onDepart: () {},
        );

        final initial = SaveEnvelopeV1.initial();
        final chosen = initial.copyWith(playerCharacterId: 'CHAR_D');
        await capture('player-choice', onboarding(initial));
        await capture('tutorial-intro', onboarding(chosen));
        await capture(
          'departure',
          onboarding(chosen.copyWith(completedStageIds: const ['r01-c01-s01'])),
        );

        // Existing owners retain D/J. The player is A, so the captured collection
        // shows rescued companions, not automatic player-avatar ownership.
        final existing = initial.copyWith(
          playerCharacterId: 'CHAR_A',
          onboardingCompleted: true,
          completedStageIds: const ['r01-c01-s01', 'r01-c06-s10'],
          unlockedCharacterIds: const ['CHAR_D', 'CHAR_J'],
          viewedStoryIds: const [
            'expedition-join-CHAR_D',
            'expedition-join-CHAR_J',
          ],
        );
        await capture(
          'companion-collection',
          CompanionCollectionScreen(save: existing, onBack: () {}),
        );
        for (final id in const ['CHAR_D', 'CHAR_J']) {
          await capture(
            'arrival-${id.substring('CHAR_'.length).toLowerCase()}',
            CompanionArrivalScreen(
              recruitment: companionRecruitmentById(id)!,
              onContinue: () {},
            ),
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
