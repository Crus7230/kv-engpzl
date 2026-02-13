import 'package:audioplayers/audioplayers.dart';

import 'settings_manager.dart';

class SoundManager {
  SoundManager._internal();
  static final SoundManager instance = SoundManager._internal();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

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

  Future<void> playBgm([int index = 0]) async {
    if (!SettingsManagerHolder.settings.bgmOn) return;
    final safeIndex = index % _bgmFiles.length;
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.play(AssetSource('audio/${_bgmFiles[safeIndex]}'));
    await _bgmPlayer.setVolume(SettingsManagerHolder.settings.bgmVolume);
  }

  Future<void> stopBgm() async {
    await _bgmPlayer.stop();
  }

  Future<void> playTap() async {
    if (!SettingsManagerHolder.settings.sfxOn) return;
    await _sfxPlayer.play(
      AssetSource('audio/tap_01.mp3'),
      volume: SettingsManagerHolder.settings.sfxVolume,
    );
  }

  Future<void> playWin() async {
    if (!SettingsManagerHolder.settings.sfxOn) return;
    await _sfxPlayer.play(
      AssetSource('audio/win.mp3'),
      volume: SettingsManagerHolder.settings.sfxVolume,
    );
  }

  Future<void> applySettings() async {
    await _bgmPlayer.setVolume(
      SettingsManagerHolder.settings.bgmOn ? SettingsManagerHolder.settings.bgmVolume : 0,
    );
    await _sfxPlayer.setVolume(
      SettingsManagerHolder.settings.sfxOn ? SettingsManagerHolder.settings.sfxVolume : 0,
    );
  }
}

class SettingsManagerHolder {
  static late SettingsManager settings;
}
