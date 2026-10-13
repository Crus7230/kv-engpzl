import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kvm/app/math_adventure_app.dart';
import 'package:kvm/core/updates/app_update_service.dart';
import 'package:kvm/core/updates/startup_update_gate.dart';
import 'package:kvm/features/garden/presentation/garden_screens.dart';
import 'package:kvm/features/progress/progress.dart';

Map<String, dynamic> _release({
  int code = 5,
  String version = '0.1.4',
  bool draft = false,
}) => {
  'tag_name': 'v$version-r1-alpha',
  'draft': draft,
  'prerelease': true,
  'published_at': '2026-10-11T00:00:00Z',
  'body':
      '<!-- kvm-update: ${jsonEncode({'schema': 1, 'versionName': version, 'versionCode': code})} -->',
  'assets': [
    <String, dynamic>{
      'name': 'KVM-R1-$version-alpha.apk',
      'state': 'uploaded',
      'size': 56 * 1024 * 1024,
      'digest': 'sha256:${'a' * 64}',
      'browser_download_url':
          'https://github.com/Crus7230/kv-engpzl/releases/download/v$version-r1-alpha/KVM-R1-$version-alpha.apk',
    },
  ],
};

AppUpdateRelease get _available =>
    AppUpdateRelease.select([_release()], installedCode: 4)!;

// Update deferral must preserve an existing player's data. New-install
// onboarding is verified separately, without changing this test's intent.
SaveEnvelopeV1 _existingPlayer() => SaveEnvelopeV1.initial().copyWith(
  playerCharacterId: 'CHAR_D',
  onboardingCompleted: true,
  unlockedCharacterIds: const ['CHAR_D', 'CHAR_J'],
);

class _FakeUpdater implements AppUpdateService {
  Completer<AppUpdateRelease?>? checkFuture;
  AppUpdateRelease? available = _available;
  bool failCheck = false;
  bool failDownload = false;
  int checks = 0;
  int downloads = 0;
  int installs = 0;
  int permissions = 0;
  AppUpdateInstallResult result = AppUpdateInstallResult.launched;

  @override
  Future<AppUpdateRelease?> check() async {
    checks++;
    if (failCheck) throw StateError('Offline');
    return checkFuture == null ? available : checkFuture!.future;
  }

  @override
  Future<void> download(AppUpdateRelease release) async {
    downloads++;
    if (failDownload) throw StateError('Download failed');
  }

  @override
  Future<AppUpdateInstallResult> install() async {
    installs++;
    return result;
  }

  @override
  Future<void> openInstallPermission() async {
    permissions++;
  }
}

Future<void> _mount(
  WidgetTester tester,
  _FakeUpdater service, {
  Duration minimumIntroDuration = Duration.zero,
  bool preparationReady = true,
  VoidCallback? onReady,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(680, 300);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.3),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: StartupUpdateGate(
        service: service,
        minimumIntroDuration: minimumIntroDuration,
        preparationReady: preparationReady,
        onReady: onReady,
        child: const Scaffold(body: Text('game')),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('intro holds while real preparation runs and notifies once', (
    tester,
  ) async {
    final service = _FakeUpdater()..failCheck = true;
    var readyCount = 0;
    await _mount(
      tester,
      service,
      minimumIntroDuration: const Duration(milliseconds: 2400),
      preparationReady: false,
      onReady: () => readyCount++,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('game'), findsNothing);
    expect(readyCount, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('game'), findsNothing);
    await _mount(
      tester,
      service,
      minimumIntroDuration: const Duration(milliseconds: 2400),
      onReady: () => readyCount++,
    );
    expect(find.text('game'), findsOneWidget);
    expect(readyCount, 1);
    await tester.pumpAndSettle();
    expect(service.checks, 1);
    expect(readyCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing during the intro never fires a late ready callback', (
    tester,
  ) async {
    final service = _FakeUpdater()..failCheck = true;
    var readyCount = 0;
    await _mount(
      tester,
      service,
      minimumIntroDuration: const Duration(milliseconds: 2400),
      onReady: () => readyCount++,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(readyCount, 0);
    expect(tester.takeException(), isNull);
  });

  test(
    'selects highest published compatible alpha code, not tag lexicography',
    () {
      final selected = AppUpdateRelease.select([
        _release(),
        _release(code: 6, version: '0.1.10'),
      ], installedCode: 4);
      expect(selected!.versionCode, 6);
      expect(selected.versionName, '0.1.10');
      expect(
        AppUpdateRelease.select([_release(code: 4)], installedCode: 4),
        isNull,
      );
      expect(
        AppUpdateRelease.select([_release(code: 3)], installedCode: 4),
        isNull,
      );
    },
  );
  test(
    'malformed, draft, foreign, missing-digest and ambiguous assets fail closed',
    () {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (r) => r['draft'] = true,
        (r) => r['published_at'] = null,
        (r) => r['tag_name'] = 'v0.1.4-beta',
        (r) => r['body'] = '<!-- kvm-update: {broken} -->',
        (r) => (r['assets'] as List).add((r['assets'] as List).first),
        (r) => r['assets'][0]['name'] = 'logic-only.apk',
        (r) => r['assets'][0]['digest'] = null,
        (r) => r['assets'][0]['size'] = 200 * 1024 * 1024,
        (r) => r['assets'][0]['browser_download_url'] =
            'http://github.com/Crus7230/kv-engpzl/x.apk',
        (r) => r['assets'][0]['browser_download_url'] =
            'https://example.com/update.apk',
        (r) => r['assets'][0]['browser_download_url'] += '?redirect=evil',
      ]) {
        final invalid = _release();
        mutate(invalid);
        expect(AppUpdateRelease.select([invalid], installedCode: 4), isNull);
        expect(
          AppUpdateRelease.select([invalid, _release()], installedCode: 4),
          isNotNull,
        );
      }
    },
  );
  testWidgets(
    'available prompt fits short screen and deferral has no download',
    (tester) async {
      final service = _FakeUpdater();
      await _mount(tester, service);
      expect(find.text('새 버전 0.1.4'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('나중에 · 계속하기'));
      await tester.pump();
      expect(find.text('game'), findsOneWidget);
      expect(service.checks, 1);
      expect(service.downloads, 0);
      expect(service.installs, 0);
    },
  );
  testWidgets('offline and timeout never block playing or prompt later', (
    tester,
  ) async {
    final offline = _FakeUpdater()..failCheck = true;
    await _mount(tester, offline);
    expect(find.text('game'), findsOneWidget);
    final delayed = _FakeUpdater()
      ..checkFuture = Completer<AppUpdateRelease?>();
    await tester.pumpWidget(const SizedBox());
    await _mount(tester, delayed);
    expect(find.text('GitHub의 새 버전을 확인하고 있어요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(find.text('game'), findsOneWidget);
    delayed.checkFuture!.complete(_available);
    await tester.pump();
    expect(find.text('새 버전 0.1.4'), findsNothing);
  });
  testWidgets(
    'download, install permission and installer retry do not redownload',
    (tester) async {
      final service = _FakeUpdater()
        ..result = AppUpdateInstallResult.permissionRequired;
      await _mount(tester, service);
      await tester.tap(find.text('업데이트 다운로드'));
      await tester.pump();
      expect(service.downloads, 1);
      expect(service.installs, 1);
      await tester.tap(find.text('설치 허용 설정'));
      await tester.pump();
      expect(service.permissions, 1);
      service.result = AppUpdateInstallResult.launched;
      await tester.tap(find.text('설치 다시 열기'));
      await tester.pump();
      expect(service.downloads, 1);
      expect(service.installs, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed download offers retry or existing game', (tester) async {
    final service = _FakeUpdater()..failDownload = true;
    await _mount(tester, service);
    await tester.tap(find.text('업데이트 다운로드'));
    await tester.pump();
    expect(service.installs, 0);
    service.failDownload = false;
    await tester.tap(find.text('업데이트 다운로드'));
    await tester.pump();
    expect(service.downloads, 2);
    expect(service.installs, 1);
    await tester.tap(find.text('나중에 · 계속하기'));
    await tester.pump();
    expect(find.text('game'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'native service uses installed code and fails open on network errors',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(AndroidAppUpdateService.channel, (
              call,
            ) async {
              expect(call.method, 'check');
              return {
                'versionCode': 4,
                'releasesJson': jsonEncode([_release()]),
              };
            });
        expect((await const AndroidAppUpdateService().check())!.versionCode, 5);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              AndroidAppUpdateService.channel,
              (_) async => throw PlatformException(code: 'NETWORK'),
            );
        expect(await const AndroidAppUpdateService().check(), isNull);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(AndroidAppUpdateService.channel, null);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
  testWidgets(
    'startup update deferral preserves campaign and stored progress',
    (tester) async {
      final store = MemoryKeyValueSaveStore();
      final repository = ProgressRepository(
        store,
        initialFactory: _existingPlayer,
      );
      final before = await repository.load();
      final updater = _FakeUpdater();
      await tester.pumpWidget(
        MathAdventureApp(
          repository: repository,
          assetBundle: rootBundle,
          updateService: updater,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('새 버전 0.1.4'), findsOneWidget);
      await tester.tap(find.text('나중에 · 계속하기'));
      await tester.pumpAndSettle();
      expect(find.byType(WorldMapScreen), findsOneWidget);
      expect((await repository.load()).toJson(), before.toJson());
    },
  );
}
