import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/app/math_adventure_app.dart';
import 'package:kvm/core/audio/audio_controller.dart';
import 'package:kvm/core/audio/audio_settings.dart';
import 'package:kvm/features/progress/progress.dart';

import 'support/compact_preview.dart';

class _Backend implements AudioBackend {
  final music = <String?>[];
  @override
  bool get mediaAvailable => true;
  @override
  bool get supportsDownload => false;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> downloadAssets() async {}
  @override
  Future<void> setMusic({
    required String? assetPath,
    required double volume,
    required bool active,
  }) async => music.add(assetPath);
  @override
  Future<void> playEffect(PuzzleSound sound, double volume) async {}
  @override
  void unlock() {}
  @override
  Future<void> suspend() async {}
  @override
  Future<void> dispose() async {}
}

class _Store extends MemoryKeyValueSaveStore {
  Completer<void>? gate;
  bool failWrites = false;
  @override
  Future<void> write(String key, String value) async {
    await gate?.future;
    if (failWrites) throw StateError('Test storage failure');
    await super.write(key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCompactPreviewFonts);
  for (final size in [
    const Size(568, 256),
    const Size(640, 280),
    const Size(680, 300),
  ]) {
    testWidgets('compact map and live saved song at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final store = _Store();
      addTearDown(() {
        if (store.gate != null && !store.gate!.isCompleted)
          store.gate!.complete();
      });
      final repo = ProgressRepository(
        store,
        initialFactory: () => SaveEnvelopeV1.initial().copyWith(
          onboardingCompleted: true,
          playerCharacterId: 'CHAR_A',
          unlockedCharacterIds: ['CHAR_A'],
          audio: AudioSettings(downloadPromptSeen: true),
        ),
      );
      final backend = _Backend();
      final audio = AudioController(backend);
      addTearDown(audio.dispose);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('compact-preview'),
          child: MathAdventureApp(
            repository: repo,
            audioController: audio,
            assetBundle: rootBundle,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      final mapRect = tester.getRect(
        find.byKey(const Key('world-map-artwork')),
      );
      expect(mapRect.height, greaterThan(size.height - 70));
      expect(
        tester.getSize(find.byKey(const Key('world-review'))).width,
        lessThanOrEqualTo(52),
      );
      expect(tester.takeException(), isNull);
      await captureCompactPreview(
        tester,
        const Key('compact-preview'),
        'map-${size.width.toInt()}',
      );
      final before = (await repo.load()).toJson()
        ..remove('generation')
        ..remove('audio');
      await tester.tap(find.byTooltip('음악·효과음 및 접근성 설정'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('responsive-settings-dialog')),
        findsOneWidget,
      );
      store.gate = Completer<void>();
      final first = find.byKey(const Key('audio-track-bgm04'));
      await tester.ensureVisible(first);
      await tester.tap(first);
      await tester.pump();
      final last = find.byKey(const Key('audio-track-bgm06'));
      await tester.ensureVisible(last);
      await tester.tap(last);
      await tester.pump();
      await audio.flush();
      expect(backend.music.last, 'assets/audio/bgm06.mp3');
      final requests = backend.music.length;
      store.gate!.complete();
      store.gate = null;
      await tester.pumpAndSettle();
      await audio.flush();
      expect(
        backend.music.skip(requests),
        isNot(contains('assets/audio/bgm04.mp3')),
      );
      final saved = await repo.load();
      expect(saved.audio.musicTrackId, 'bgm06');
      expect(
        saved.toJson()
          ..remove('generation')
          ..remove('audio'),
        before,
      );
      await captureCompactPreview(
        tester,
        const Key('compact-preview'),
        'music-${size.width.toInt()}',
      );
      await tester.tap(find.byTooltip('설정 닫기'));
      await tester.pumpAndSettle();
      expect(
        (await ProgressRepository(store).load()).audio.musicTrackId,
        'bgm06',
      );
      // A failed auto-save restores the persisted song, not an unsaved choice.
      await tester.tap(find.byTooltip('음악·효과음 및 접근성 설정'));
      await tester.pumpAndSettle();
      store.failWrites = true;
      final rejected = find.byKey(const Key('audio-track-intro'));
      await tester.ensureVisible(rejected);
      await tester.tap(rejected);
      await tester.pumpAndSettle();
      await audio.flush();
      expect(backend.music.last, 'assets/audio/bgm06.mp3');
      expect((await repo.load()).audio.musicTrackId, 'bgm06');
      expect(find.text('음악 설정을 저장하지 못해 이전 설정으로 돌아왔습니다.'), findsOneWidget);
      await tester.tap(find.byTooltip('설정 닫기'));
      await tester.pumpAndSettle();
      store.failWrites = false;
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await audio.dispose();
    });
  }
}
