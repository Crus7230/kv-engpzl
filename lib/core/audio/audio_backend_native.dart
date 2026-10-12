import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_controller.dart';
import 'audio_settings.dart';

AudioBackend createAudioBackend() => NativeAudioBackend();

class NativeAudioBackend implements AudioBackend {
  static const channel = MethodChannel('kvm/audio');
  bool get _supported => defaultTargetPlatform == TargetPlatform.android;
  bool _available = false;
  bool _bridgeReady = false;
  @override
  bool get mediaAvailable => _available;
  @override
  bool get supportsDownload => _supported && _bridgeReady;
  @override
  Future<void> initialize() async {
    if (!_supported) return;
    final manifest = jsonDecode(
      await rootBundle.loadString('assets/audio_manifest.json'),
    );
    try {
      _available =
          await channel.invokeMethod<bool>('initialize', manifest) ?? false;
      _bridgeReady = true;
    } on PlatformException catch (error) {
      if (error.code != 'AUDIO_PACK_UNAVAILABLE') rethrow;
      // A corrupt/missing pack is recoverable by an explicit re-download.
      _bridgeReady = true;
      _available = false;
    }
  }

  @override
  Future<void> downloadAssets() async {
    if (_supported)
      _available = await channel.invokeMethod<bool>('download') ?? false;
  }

  @override
  Future<void> setMusic({
    required String? assetPath,
    required double volume,
    required bool active,
  }) async {
    if (_supported)
      await channel.invokeMethod<void>('music', {
        'path': assetPath,
        'volume': volume,
        'active': active,
      });
  }

  @override
  Future<void> playEffect(PuzzleSound sound, double volume) async {
    if (_supported)
      await channel.invokeMethod<void>('effect', {
        'sound': sound.name,
        'volume': volume,
      });
  }

  @override
  void unlock() {
    if (_supported && _available) {
      // Ignore platform disposal/focus errors; audio cannot break interaction.
      channel.invokeMethod<void>('unlock').catchError((Object _) {});
    }
  }

  @override
  Future<void> suspend() async {
    if (_supported) await channel.invokeMethod<void>('suspend');
  }

  @override
  Future<void> dispose() async {
    if (_supported) await channel.invokeMethod<void>('dispose');
  }
}
