import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/core/theme/app_theme.dart';
import 'package:kvm/features/campaign/data/initial_campaign.dart';
import 'package:kvm/features/discovery/data/discovery_runtime_catalog.dart';
import 'package:kvm/features/discovery/domain/discovery_models.dart';
import 'package:kvm/features/discovery/presentation/discovery_board_motion.dart';
import 'package:kvm/features/discovery/presentation/discovery_puzzle_screen.dart';
import 'package:kvm/features/discovery/presentation/engine_discovery_puzzle_view_model.dart';

void _swap(EngineDiscoveryPuzzleViewModel model, DiscoveryTutorialStep step) {
  model.selectGem(step.from.row * model.boardColumns + step.from.column);
  model.selectGem(step.to.row * model.boardColumns + step.to.column);
}

// Real authored stages, rendered on a simulated Flutter viewport. These frames
// document motion only; they are not Android performance measurements/goldens.
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

  for (final preview in [
    (
      name: 'r1-swap-discovery',
      id: 'r01-c01-s01',
      config: DiscoveryBoardConfig.compactPhone,
    ),
    (
      name: 'r1-power-cascade',
      id: 'r01-c05-s08',
      config: DiscoveryBoardConfig.compactPhone,
    ),
    (
      name: 'r1-power-birth-cascade',
      id: 'r01-c06-s07',
      config: DiscoveryBoardConfig.standardPhone,
    ),
  ]) {
    testWidgets('record ${preview.name} at 800x360', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 360);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final stage = initialCampaign.stageById(preview.id)!;
      final model = EngineDiscoveryPuzzleViewModel(
        boardConfig: preview.config,
        stage: stage,
      );
      addTearDown(model.dispose);
      final path = discoveryRuntimeCatalog.resolve(stage).referencePathFor!(
        stage.boardVariants.variantFor(preview.config),
      );
      var bestScore = -1;
      var stepIndex = 0;
      Map<String, Object?>? checkpoint;
      for (var index = 0; index < path.length; index++) {
        final before = model.exportSession();
        _swap(model, path[index]);
        final trace = model.boardTurnMotion!;
        final score =
            trace.cascades.length +
            trace.cascades.fold<int>(
              0,
              (sum, cascade) => sum + cascade.activatedPowers.length * 10,
            );
        if (score > bestScore) {
          bestScore = score;
          stepIndex = index;
          checkpoint = before;
        }
      }
      model.restoreSession(checkpoint!);
      final boundaryKey = GlobalKey();
      final theme = AppTheme.light();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'KvmPreviewKorean'),
            primaryTextTheme: theme.primaryTextTheme.apply(
              fontFamily: 'KvmPreviewKorean',
            ),
          ),
          builder: (context, child) =>
              RepaintBoundary(key: boundaryKey, child: child!),
          home: DiscoveryPuzzleScreen(viewModel: model),
        ),
      );
      await tester.pumpAndSettle();
      final directory = Directory('build/previews/motion-${preview.name}');
      await tester.runAsync(() => directory.create(recursive: true));
      Future<void> capture(int frame) async {
        expect(
          tester.takeException(),
          isNull,
          reason: '${preview.name} frame $frame',
        );
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final rendered = await boundary.toImage(pixelRatio: 1);
          final data = await rendered.toByteData(
            format: ui.ImageByteFormat.png,
          );
          rendered.dispose();
          await File(
            '${directory.path}/frame-${frame.toString().padLeft(3, '0')}.png',
          ).writeAsBytes(data!.buffer.asUint8List(), flush: true);
        });
      }

      await capture(0);
      _swap(model, path[stepIndex]);
      final trace = model.boardTurnMotion!;
      if (preview.name.contains('power')) {
        expect(
          trace.cascades.any((cascade) => cascade.activatedPowers.isNotEmpty),
          isTrue,
        );
      }
      final savedAfter = jsonEncode(model.exportSession());
      final timeline = discoveryMotionTimeline(
        trace,
        columns: model.boardColumns,
      );
      await tester.pump();
      var elapsed = 0;
      var frame = 1;
      const frameMilliseconds = 20;
      while (elapsed <= timeline.duration.inMilliseconds + 200) {
        await capture(frame++);
        await tester.pump(const Duration(milliseconds: frameMilliseconds));
        elapsed += frameMilliseconds;
      }
      await tester.pumpAndSettle();
      expect(jsonEncode(model.exportSession()), savedAfter);
      expect(tester.takeException(), isNull);
      // A binary artifact, not source content. The manifest prevents a reused
      // frame directory's stale tail from entering an assembled animation.
      await tester.runAsync(
        () => File('${directory.path}/capture.json').writeAsString(
          jsonEncode({
            'stageId': stage.id,
            'stepIndex': stepIndex,
            'frames': frame,
            'frameMilliseconds': frameMilliseconds,
            'turnMilliseconds': timeline.duration.inMilliseconds,
            'cascades': trace.cascades.length,
            'powerActivations': trace.cascades.fold<int>(
              0,
              (sum, cascade) => sum + cascade.activatedPowers.length,
            ),
            'viewport': '800x360 Flutter simulated',
          }),
        ),
      );
    });
  }
}
