import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import 'settings_manager.dart';

class SoundManager {
  SoundManager._internal();
  static final SoundManager instance = SoundManager._internal();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  bool _initialized = false;
  bool _appInForeground = true;
  bool _resumeBgmOnForeground = false;
  int _currentTrackIndex = 0;

  final List<String> _bgmFiles = const [
    '01_bgm_SandCastle.mp3',
    '02_bgm_HappyMistake.mp3',
    '03_bgm_Kazoom.mp3',
    '04_bgm_SummerShower.mp3',
    '05_bgm_Fantasyland.mp3',
    '06_bgm_PoniesandBalloons.mp3',
    '07_bgm_UkuleleBeach.mp3',
    '08_bgm_AfterSchoolJamboree.mp3',
  ];

  final List<String> _bgmTitles = const [
    'Sand Castle',
    'Happy Mistake',
    'Kazoom',
    'Summer Shower',
    'Fantasyland',
    'Ponies and Balloons',
    'Ukulele Beach',
    'After School Jamboree',
  ];

  List<String> get bgmTitles => _bgmTitles;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _bgmPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _sfxPlayer.setPlayerMode(PlayerMode.lowLatency);
    await _sfxPlayer.setReleaseMode(ReleaseMode.stop);
    _initialized = true;
  }

  Future<void> playBgm([int index = 0]) async {
    await _ensureInitialized();
    _currentTrackIndex = index % _bgmFiles.length;
    if (!_appInForeground) return;
    if (!SettingsManagerHolder.settings.bgmOn) return;
    await _bgmPlayer.play(AssetSource('audio/${_bgmFiles[_currentTrackIndex]}'));
    await _bgmPlayer.setVolume(SettingsManagerHolder.settings.bgmVolume);
  }

  Future<void> stopBgm() async {
    await _ensureInitialized();
    await _bgmPlayer.stop();
  }

  Future<void> playTap() async {
    await _ensureInitialized();
    if (!_appInForeground) return;
    if (!SettingsManagerHolder.settings.sfxOn) return;
    await _sfxPlayer.play(
      AssetSource('audio/tap_01.mp3'),
      volume: SettingsManagerHolder.settings.sfxVolume,
    );
  }

  Future<void> playWin() async {
    await _ensureInitialized();
    if (!_appInForeground) return;
    if (!SettingsManagerHolder.settings.sfxOn) return;
    await _sfxPlayer.play(
      AssetSource('audio/win.mp3'),
      volume: SettingsManagerHolder.settings.sfxVolume,
    );
  }

  Future<void> applySettings() async {
    await _ensureInitialized();
    await _bgmPlayer.setVolume(
      SettingsManagerHolder.settings.bgmOn ? SettingsManagerHolder.settings.bgmVolume : 0,
    );
    await _sfxPlayer.setVolume(
      SettingsManagerHolder.settings.sfxOn ? SettingsManagerHolder.settings.sfxVolume : 0,
    );
    if (!SettingsManagerHolder.settings.bgmOn) {
      await _bgmPlayer.stop();
      return;
    }
    if (_appInForeground) {
      await playBgm(SettingsManagerHolder.settings.bgmTrackIndex);
    }
  }

  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    await _ensureInitialized();
    if (state == AppLifecycleState.resumed) {
      _appInForeground = true;
      if (_resumeBgmOnForeground && SettingsManagerHolder.settings.bgmOn) {
        await playBgm(_currentTrackIndex);
      }
      _resumeBgmOnForeground = false;
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _resumeBgmOnForeground = SettingsManagerHolder.settings.bgmOn && _appInForeground;
      _appInForeground = false;
      await _bgmPlayer.stop();
      await _sfxPlayer.stop();
    }
  }
}

class SettingsManagerHolder {
  static late SettingsManager settings;
}
