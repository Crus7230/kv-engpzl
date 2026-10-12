import 'dart:async';

import 'audio_settings.dart';

abstract interface class AudioBackend {
  bool get mediaAvailable;
  bool get supportsDownload;
  Future<void> initialize();
  Future<void> downloadAssets();
  Future<void> setMusic({
    required String? assetPath,
    required double volume,
    required bool active,
  });
  Future<void> playEffect(PuzzleSound sound, double volume);
  // Called directly within a pointer event to satisfy browser autoplay rules.
  void unlock();
  Future<void> suspend();
  Future<void> dispose();
}

/// Serial music changes use the latest desired state, not stale queued scenes.
/// Lifecycle suspension is immediate, even while preparation is in flight.
class AudioController {
  AudioController(this.backend, {this.onError, this.onChanged, this.onHaptic});
  final AudioBackend backend;
  final void Function(Object error)? onError;
  final void Function()? onChanged;
  final Future<void> Function(PuzzleHaptic cue)? onHaptic;
  AudioSettings _settings = AudioSettings();
  AudioScene _scene = AudioScene.intro;
  bool _active = false;
  bool _disposed = false;
  bool _ready = false;
  Future<void>? _initializing;
  Future<void> _tail = Future<void>.value();
  String? _lastRequest;
  int _musicEpoch = 0;
  final Map<PuzzleSound, DateTime> _lastEffect = {};
  final Map<PuzzleHaptic, DateTime> _lastHaptic = {};

  AudioSettings get settings => _settings;
  AudioScene get scene => _scene;
  bool get mediaAvailable => _ready && backend.mediaAvailable;
  bool get supportsDownload => backend.supportsDownload;

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    try {
      await backend.initialize();
      if (_disposed) return;
      _ready = true;
      _queueSync();
      onChanged?.call();
    } catch (error) {
      if (!_disposed) onError?.call(error);
    }
  }

  void configure(AudioSettings settings, AudioScene scene) {
    if (_disposed) return;
    _settings = settings;
    _scene = scene;
    _queueSync();
  }

  void setForeground(bool active) {
    if (_disposed || active == _active) return;
    _active = active;
    if (!active) {
      _musicEpoch++;
      _lastRequest = null;
      _ignoreErrors(backend.suspend());
    }
    _queueSync();
  }

  void unlock() {
    if (!_disposed && _active) backend.unlock();
  }

  void play(PuzzleSound sound) {
    haptic(switch (sound) {
      PuzzleSound.select => PuzzleHaptic.select,
      PuzzleSound.swap => PuzzleHaptic.swap,
      PuzzleSound.pop || PuzzleSound.special => PuzzleHaptic.match,
    });
    if (_disposed ||
        !mediaAvailable ||
        !_active ||
        !_settings.effectsEnabled ||
        _settings.effectsVolume == 0)
      return;
    final now = DateTime.now();
    final previous = _lastEffect[sound];
    if (previous != null && now.difference(previous).inMilliseconds < 45)
      return;
    _lastEffect[sound] = now;
    // Never queue sounds behind music loads or replay them after returning.
    _ignoreErrors(backend.playEffect(sound, _settings.effectsVolume));
  }

  void haptic(PuzzleHaptic cue) {
    if (_disposed || !_active || !_settings.hapticsEnabled || onHaptic == null)
      return;
    final now = DateTime.now();
    final previous = _lastHaptic[cue];
    if (previous != null && now.difference(previous).inMilliseconds < 70)
      return;
    _lastHaptic[cue] = now;
    _ignoreErrors(onHaptic!(cue));
  }

  void _queueSync() {
    if (!mediaAvailable || _disposed) return;
    _tail = _tail
        .then((_) async {
          if (_disposed) return;
          final id = _scene == AudioScene.intro
              ? _settings.introTrackId
              : _settings.gameTrackId;
          final path = _settings.musicEnabled
              ? audioTracks.firstWhere((track) => track.id == id).assetPath
              : null;
          final audible =
              _active &&
              ((_settings.musicEnabled && _settings.musicVolume > 0) ||
                  (_settings.effectsEnabled && _settings.effectsVolume > 0));
          final epoch = _musicEpoch;
          final request = '$epoch|$path|${_settings.musicVolume}|$audible';
          if (request == _lastRequest) return;
          await backend.setMusic(
            assetPath: path,
            volume: _settings.musicVolume,
            active: audible,
          );
          if (epoch == _musicEpoch) _lastRequest = request;
        })
        .catchError((Object error) {
          _lastRequest = null;
          if (!_disposed) onError?.call(error);
        });
  }

  void _ignoreErrors(Future<void> operation) {
    unawaited(
      operation.catchError((Object error) {
        if (!_disposed) onError?.call(error);
      }),
    );
  }

  Future<void> flush() => _tail;

  Future<void> downloadAssets() async {
    await initialize();
    if (_disposed || !supportsDownload) return;
    await backend.downloadAssets();
    if (_disposed) return;
    _lastRequest = null;
    _queueSync();
    onChanged?.call();
    await flush();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await backend.suspend();
      await _initializing;
      await _tail;
    } catch (error) {
      onError?.call(error);
    } finally {
      try {
        await backend.dispose();
      } catch (error) {
        onError?.call(error);
      }
    }
  }
}
