import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/core/audio/audio_backend_native.dart';
import 'package:kvm/core/audio/audio_options.dart';
import 'package:kvm/core/audio/audio_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeAudioBackend.channel, null);
  });

  test('audio-v2 manifest is passed before an explicit download', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeAudioBackend.channel, (call) async {
          calls.add(call);
          return call.method == 'download' ? true : false;
        });
    final backend = NativeAudioBackend();
    await backend.initialize();
    expect(calls.single.method, 'initialize');
    final manifest = calls.single.arguments as Map;
    expect(manifest['packId'], 'audio-v2');
    expect(manifest['manifestVersion'], 1);
    expect(manifest['assets'], hasLength(11));
    expect(
      manifest['download']['url'],
      'https://github.com/Crus7230/kv-engpzl/releases/download/'
      'media-audio-v2/KVM-audio-v2.zip',
    );
    expect(backend.mediaAvailable, isFalse);
    expect(backend.supportsDownload, isTrue);
    await backend.downloadAssets();
    expect(calls.map((call) => call.method), ['initialize', 'download']);
    expect(backend.mediaAvailable, isTrue);
  });

  test('unavailable current pack remains explicitly recoverable', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeAudioBackend.channel, (call) async {
          calls.add(call.method);
          if (call.method == 'initialize') {
            throw PlatformException(code: 'AUDIO_PACK_UNAVAILABLE');
          }
          return true;
        });
    final backend = NativeAudioBackend();
    await backend.initialize();
    expect(calls, ['initialize']);
    expect(backend.mediaAvailable, isFalse);
    expect(backend.supportsDownload, isTrue);
    await backend.downloadAssets();
    expect(calls, ['initialize', 'download']);
    expect(backend.mediaAvailable, isTrue);
  });

  testWidgets('missing audio-v2 offers one consented 30MB download', (
    tester,
  ) async {
    var downloads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AudioOptions(
              settings: AudioSettings(),
              onChanged: (_) {},
              mediaAvailable: false,
              onDownload: () => downloads++,
            ),
          ),
        ),
      ),
    );
    expect(downloads, 0);
    expect(find.text('음원 받기 · 약 30MB, 팩당 1회'), findsOneWidget);
    await tester.tap(find.byKey(const Key('download-audio')));
    expect(downloads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('installed pack hides download and in-flight pack disables it', (
    tester,
  ) async {
    Widget options({required bool available, bool downloading = false}) =>
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AudioOptions(
                settings: AudioSettings(),
                onChanged: (_) {},
                mediaAvailable: available,
                onDownload: () {},
                downloading: downloading,
              ),
            ),
          ),
        );
    await tester.pumpWidget(options(available: true));
    expect(find.byKey(const Key('download-audio')), findsNothing);
    await tester.pumpWidget(options(available: false, downloading: true));
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('download-audio')))
          .onPressed,
      isNull,
    );
    expect(find.text('음원 다운로드·검증 중…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final track in audioTracks.skip(4)) {
    testWidgets('new song ${track.id} is selectable in music options', (
      tester,
    ) async {
      var settings = AudioSettings();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => AudioOptions(
                  settings: settings,
                  onChanged: (value) => setState(() => settings = value),
                  mediaAvailable: true,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('audio-track-default')), findsOneWidget);
      for (final item in audioTracks) {
        expect(find.byKey(Key('audio-track-${item.id}')), findsOneWidget);
      }
      final tile = find.byKey(Key('audio-track-${track.id}'));
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(settings.musicTrackId, track.id);
      expect(settings.trackFor(AudioScene.intro), track.id);
      expect(settings.trackFor(AudioScene.adventure), track.id);
      expect(tester.takeException(), isNull);
    });
  }
}
