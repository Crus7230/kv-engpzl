import 'dart:async';

import 'package:flutter/material.dart';

import '../branding/garden_branding.dart';
import 'app_update_service.dart';

/// Checks once per cold start while the app prepares its existing save/assets.
/// No save mutation or forced update; installation still requires Android UI.
class StartupUpdateGate extends StatefulWidget {
  const StartupUpdateGate({
    required this.service,
    required this.child,
    this.onReady,
    this.minimumIntroDuration = Duration.zero,
    this.preparationReady = true,
    this.introBuilder,
    super.key,
  });

  final AppUpdateService service;
  final Widget child;
  final VoidCallback? onReady;
  final Duration minimumIntroDuration;
  final bool preparationReady;
  final Widget Function(BuildContext context, bool checking)? introBuilder;

  @override
  State<StartupUpdateGate> createState() => _StartupUpdateGateState();
}

class _StartupUpdateGateState extends State<StartupUpdateGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _introClock;
  bool _introElapsed = false;
  bool _readyNotified = false;
  bool _checking = true;
  bool _working = false;
  bool _downloaded = false;
  AppUpdateRelease? _release;
  String? _message;
  bool _permissionRequired = false;

  @override
  void initState() {
    super.initState();
    _introElapsed = widget.minimumIntroDuration == Duration.zero;
    _introClock =
        AnimationController(vsync: this, duration: widget.minimumIntroDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              setState(() => _introElapsed = true);
              _notifyReady();
            }
          });
    // A finite clock keeps the intro on screen while preparation runs. It
    // does not animate scenery, so reduced-motion users get the same hold.
    if (!_introElapsed) _introClock.forward();
    unawaited(_check());
  }

  @override
  void didUpdateWidget(StartupUpdateGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    _notifyReady();
  }

  @override
  void dispose() {
    _introClock.dispose();
    super.dispose();
  }

  void _notifyReady() {
    if (_readyNotified ||
        _checking ||
        !_introElapsed ||
        !widget.preparationReady ||
        _release != null) {
      return;
    }
    _readyNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady?.call();
    });
  }

  Future<void> _check() async {
    AppUpdateRelease? release;
    try {
      release = await widget.service.check().timeout(
        const Duration(seconds: 5),
      );
    } catch (_) {
      // This optional check can never replace the app's own recovery screens.
    }
    if (mounted)
      setState(() {
        _release = release;
        _checking = false;
      });
    if (mounted) _notifyReady();
  }

  Future<void> _update() async {
    if (_working || _release == null) return;
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      if (!_downloaded) {
        await widget.service.download(_release!);
        _downloaded = true;
      }
      if (!mounted) return;
      final result = await widget.service.install();
      if (mounted)
        setState(() {
          _permissionRequired =
              result == AppUpdateInstallResult.permissionRequired;
          _message = _permissionRequired
              ? 'Android에서 이 앱의 설치 허용이 필요합니다. 허용 후 돌아와 설치를 눌러 주세요.'
              : 'Android 설치 화면에서 업데이트를 확인해 주세요. 취소해도 기존 앱은 사용할 수 있어요.';
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _message = '업데이트를 완료하지 못했어요. 네트워크나 저장 공간을 확인하고 다시 시도해 주세요.';
        });
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _permission() async {
    if (_working) return;
    try {
      await widget.service.openInstallPermission();
    } catch (_) {
      if (mounted)
        setState(
          () => _message = 'Android 설정을 열 수 없어요. 설정에서 이 앱의 설치 허용을 확인해 주세요.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking ||
        !_introElapsed ||
        (_release == null && !widget.preparationReady)) {
      return widget.introBuilder?.call(context, _checking) ??
          GardenLoadingScreen(
            status: _checking ? 'GitHub의 새 버전을 확인하고 있어요' : '탐험을 준비하고 있어요',
            reduceMotion: MediaQuery.disableAnimationsOf(context),
          );
    }
    final release = _release;
    if (release == null) return widget.child;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '새 버전 ${release.versionName}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _message ??
                        'GitHub에 새 APK가 있어요. 진행 기록과 정원은 유지됩니다. 다운로드 후 Android 설치 확인이 필요해요.',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '앱 APK · ${(release.bytes / 1024 / 1024).toStringAsFixed(1)} MiB · 모바일 데이터가 사용될 수 있어요. 에셋 팩은 별도로 보관합니다.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  if (_working) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 6),
                    const Text('APK를 다운로드하고 무결성과 서명을 확인하고 있어요.'),
                    const SizedBox(height: 8),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: _working ? null : _update,
                        child: Text(_downloaded ? '설치 다시 열기' : '업데이트 다운로드'),
                      ),
                      if (_permissionRequired)
                        OutlinedButton(
                          onPressed: _working ? null : _permission,
                          child: const Text('설치 허용 설정'),
                        ),
                      TextButton(
                        onPressed: _working
                            ? null
                            : () {
                                setState(() => _release = null);
                                _notifyReady();
                              },
                        child: const Text('나중에 · 계속하기'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
