import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/core/theme/app_theme.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/discovery/domain/discovery_models.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_screen.dart';
import 'package:kvm/features/discovery/presentation/engine_discovery_puzzle_view_model.dart';
import 'package:kvm/features/exploration/presentation/r1_expedition_screen.dart';
import 'package:kvm/features/garden/presentation/garden_screens.dart';

// Raster captures from actual widgets at simulated sizes, not Android captures.
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
        final loader = FontLoader(family)..addFont(Future.value(bytes));
        await loader.load();
      }
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final size in const [
    Size(800, 360),
    Size(720, 320),
    Size(680, 300),
    Size(960, 432),
  ]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('capture R2 $size text $scale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
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
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: RepaintBoundary(key: key, child: child!),
              ),
              home: screen,
            ),
          );
          await tester.runAsync(() async {
            for (final widget in tester.widgetList<Image>(find.byType(Image))) {
              await precacheImage(widget.image, key.currentContext!);
            }
          });
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$state / $size / $scale',
          );
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final rendered = await boundary.toImage(pixelRatio: 1);
            final bytes = await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            );
            rendered.dispose();
            final dir = Directory('build/previews/r2');
            await dir.create(recursive: true);
            await File(
              '${dir.path}/${state}_${size.width.toInt()}x${size.height.toInt()}_text${(scale * 100).round()}_flutter-simulated.png',
            ).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
          });
        }

        await capture(
          'world-map-floating',
          WorldMapScreen(
            unlockedRegionIds: const {
              'region-01-calculation',
              'region-02-pattern',
            },
            restoredNodeIds: const {},
            totalStars: 90,
            weeklyActions: 3,
            onReview: () {},
            onExplore: () {},
            onRestore: () {},
            onSelectRegion: (_) {},
            onSettings: () {},
            onCompanions: () {},
            reviewDetail: '돌아온 개념 · 기억 꺼내기',
            explorationDetail: 'R02 C01 S01',
          ),
        );
        final stages = initialCampaign.regions[1].stages.toList();
        Widget map(bool progressed) => R1ExpeditionScreen(
          key: ValueKey(progressed),
          regionNumber: 2,
          stages: stages,
          completedStageIds: progressed
              ? stages.take(2).map((s) => s.id).toSet()
              : const {},
          unlockedStageIds: progressed
              ? stages.take(3).map((s) => s.id).toSet()
              : const {'r02-c01-s01'},
          restoredNodeIds: progressed ? const {'r02-c01-garden-02'} : const {},
          decorationChoices: progressed
              ? const {'r02-c01-garden-02': 'herbs'}
              : const {},
          onBack: () {},
          onSelectStage: (_) {},
          onPlay: () {},
          onRestore: () {},
          hasActiveSession: false,
          canRestore: false,
          nextStageId: progressed ? 'r02-c01-s03' : 'r02-c01-s01',
          playerCharacterId: 'CHAR_D',
          unlockedCharacterIds: const {'CHAR_D', 'CHAR_J', 'CHAR_L'},
        );
        await capture('r2-forest-before', map(false));
        await capture('r2-forest-after', map(true));
        final model = EngineDiscoveryPuzzleViewModel(
          stage: initialCampaign.stageById('r02-c03-s04')!,
          boardConfig: DiscoveryBoardConfig.compactPhone,
        );
        await capture(
          'r2-parentheses-puzzle',
          DiscoveryPuzzleScreen(viewModel: model),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
      });
    }
  }
}
