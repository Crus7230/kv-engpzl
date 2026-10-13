import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/app/math_adventure_app.dart';
import 'package:kvm/core/branding/garden_branding.dart';
import 'package:kvm/core/assets/retained_asset_bundle.dart';
import 'package:kvm/core/audio/audio_controller.dart';
import 'package:kvm/core/audio/audio_settings.dart';
import 'package:kvm/features/garden/presentation/garden_screens.dart';
import 'package:kvm/features/progress/progress.dart';

// Use the same package URI as the app. The standalone Dart verifier imports
// relative URIs, which would create a second AudioBackend type in this suite.
class _StartupAudioBackend implements AudioBackend {
  final music = <(String?, double, bool)>[];
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
  }) async {
    music.add((assetPath, volume, active));
  }

  @override
  Future<void> playEffect(PuzzleSound sound, double volume) async {}
  @override
  void unlock() {}
  @override
  Future<void> suspend() async {}
  @override
  Future<void> dispose() async {}
}

class _StartupStore extends MemoryKeyValueSaveStore {
  Completer<void>? gate;
  Object? failure;
  int writes = 0;

  @override
  Future<String?> read(String key) async {
    await gate?.future;
    final error = failure;
    if (error != null) throw error;
    return super.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    await super.write(key, value);
  }
}

// These tests exercise loading/recovery for an existing player, not the new
// installation's character selection and real first-problem onboarding.
SaveEnvelopeV1 _existingPlayer() => SaveEnvelopeV1.initial().copyWith(
  playerCharacterId: 'CHAR_D',
  onboardingCompleted: true,
  unlockedCharacterIds: const ['CHAR_D', 'CHAR_J'],
);

void _viewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(680, 300);
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _boot(WidgetTester tester, _StartupStore store) async {
  _viewport(tester);
  await tester.pumpWidget(
    MathAdventureApp(
      repository: ProgressRepository(store, initialFactory: _existingPlayer),
      assetBundle: rootBundle,
      now: () => DateTime.utc(2026, 10, 11),
    ),
  );
}

void main() {
  testWidgets('saved music plays in intro and continues without a restart', (
    tester,
  ) async {
    _viewport(tester);
    final backend = _StartupAudioBackend();
    final audio = AudioController(backend);
    await tester.pumpWidget(
      MathAdventureApp(
        repository: ProgressRepository(
          MemoryKeyValueSaveStore(),
          initialFactory: () => _existingPlayer().copyWith(
            audio: AudioSettings(musicTrackId: 'bgm03'),
          ),
        ),
        assetBundle: rootBundle,
        audioController: audio,
      ),
    );
    await tester.pump();
    await audio.flush();
    expect(find.byType(AdventureIntroScreen), findsOneWidget);
    expect(find.byType(WorldMapScreen), findsNothing);
    expect(backend.music.last.$1, 'assets/audio/bgm03.mp3');
    final requests = backend.music.length;
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(AdventureIntroScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await audio.flush();
    expect(find.byType(WorldMapScreen), findsOneWidget);
    expect(backend.music.length, requests);
    expect(audio.scene, AudioScene.adventure);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('intro waits for real preparation without losing the save', (
    tester,
  ) async {
    final store = _StartupStore()..gate = Completer<void>();
    await _boot(tester, store);
    await tester.pump();
    expect(find.byType(AdventureIntroScreen), findsOneWidget);
    expect(find.text('지난 탐험 기록을 불러오고 있어요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(AdventureIntroScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    store.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(WorldMapScreen), findsOneWidget);
    expect(find.byType(AdventureIntroScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('future-version error stays visible and retries without reset', (
    tester,
  ) async {
    final store = _StartupStore()
      ..failure = const FutureSaveVersionException(999);
    await _boot(tester, store);
    await tester.pumpAndSettle();
    expect(find.text('저장된 정원을 열 수 없어요'), findsOneWidget);
    expect(find.textContaining('더 새로운 앱'), findsOneWidget);
    expect(find.byType(AdventureIntroScreen), findsNothing);
    expect(store.writes, 0);
    expect(tester.takeException(), isNull);

    store.failure = null;
    store.gate = Completer<void>();
    await tester.ensureVisible(find.text('다시 열기'));
    await tester.tap(find.text('다시 열기'));
    await tester.pump();
    expect(find.byType(AdventureIntroScreen), findsOneWidget);
    expect(find.text('저장된 정원을 열 수 없어요'), findsNothing);
    expect(store.writes, 0);
    store.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(WorldMapScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('missing media is visible during loading and can be retried', (
    tester,
  ) async {
    _viewport(tester);
    final previousPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    try {
      var available = false;
      final assetGate = Completer<void>();
      messenger.setMockMethodCallHandler(RetainedAssetBundle.channel, (
        call,
      ) async {
        if (call.method == 'ensureInstalled') {
          if (!available)
            throw PlatformException(code: 'ASSET_PACK_UNAVAILABLE');
          await assetGate.future;
          return null;
        }
        if (call.method == 'readAsset') {
          final data = await rootBundle.load(call.arguments['path'] as String);
          return data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
        }
        return null;
      });
      final store = _StartupStore()..gate = Completer<void>();
      await tester.pumpWidget(
        MathAdventureApp(
          repository: ProgressRepository(
            store,
            initialFactory: _existingPlayer,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('정원 에셋을 확인할 수 없어요'), findsOneWidget);
      expect(find.byType(AdventureIntroScreen), findsNothing);
      expect(store.writes, 0);
      expect(tester.takeException(), isNull);

      available = true;
      await tester.ensureVisible(find.text('다시 확인'));
      await tester.tap(find.text('다시 확인'));
      await tester.pump();
      expect(find.byType(AdventureIntroScreen), findsOneWidget);
      expect(find.text('정원 에셋을 확인할 수 없어요'), findsNothing);
      assetGate.complete();
      store.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(WorldMapScreen), findsOneWidget);
      expect(store.writes, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
      messenger.setMockMethodCallHandler(RetainedAssetBundle.channel, null);
    }
  });
}
