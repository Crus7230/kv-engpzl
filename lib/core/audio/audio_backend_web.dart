import 'dart:js_interop';

import 'audio_controller.dart';
import 'audio_settings.dart';

@JS('kvmAudio.initialize')
external JSPromise<JSAny?> _initialize();
@JS('kvmAudio.music')
external JSPromise<JSAny?> _music(
  JSString? path,
  JSNumber volume,
  JSBoolean active,
);
@JS('kvmAudio.effect')
external void _effect(JSString sound, JSNumber volume);
@JS('kvmAudio.unlock')
external void _unlock();
@JS('kvmAudio.suspend')
external void _suspend();
@JS('kvmAudio.dispose')
external void _dispose();

AudioBackend createAudioBackend() => WebAudioBackend();

class WebAudioBackend implements AudioBackend {
  @override
  bool get mediaAvailable => true;
  @override
  bool get supportsDownload => false;
  @override
  Future<void> downloadAssets() async {}
  @override
  Future<void> initialize() async {
    await _initialize().toDart;
  }

  @override
  Future<void> setMusic({
    required String? assetPath,
    required double volume,
    required bool active,
  }) async {
    await _music(assetPath?.toJS, volume.toJS, active.toJS).toDart;
  }

  @override
  Future<void> playEffect(PuzzleSound sound, double volume) async {
    _effect(sound.name.toJS, volume.toJS);
  }

  @override
  void unlock() => _unlock();
  @override
  Future<void> suspend() async {
    _suspend();
  }

  @override
  Future<void> dispose() async {
    _dispose();
  }
}
