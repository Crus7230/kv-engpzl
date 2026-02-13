import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager extends ChangeNotifier {
  late SharedPreferences _prefs;

  bool bgmOn = true;
  bool sfxOn = true;
  double bgmVolume = 0.4;
  double sfxVolume = 1.0;
  int bgmTrackIndex = 0;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    bgmOn = _prefs.getBool('settings_bgm_on') ?? true;
    sfxOn = _prefs.getBool('settings_sfx_on') ?? true;
    bgmVolume = _prefs.getDouble('settings_bgm_volume') ?? 0.4;
    sfxVolume = _prefs.getDouble('settings_sfx_volume') ?? 1.0;
    bgmTrackIndex = _prefs.getInt('settings_bgm_track_index') ?? 0;
  }

  Future<void> _save() async {
    await _prefs.setBool('settings_bgm_on', bgmOn);
    await _prefs.setBool('settings_sfx_on', sfxOn);
    await _prefs.setDouble('settings_bgm_volume', bgmVolume);
    await _prefs.setDouble('settings_sfx_volume', sfxVolume);
    await _prefs.setInt('settings_bgm_track_index', bgmTrackIndex);
  }

  Future<void> setBgmOn(bool value) async {
    bgmOn = value;
    await _save();
    notifyListeners();
  }

  Future<void> setSfxOn(bool value) async {
    sfxOn = value;
    await _save();
    notifyListeners();
  }

  Future<void> setBgmVolume(double value) async {
    bgmVolume = value.clamp(0.0, 1.0);
    await _save();
    notifyListeners();
  }

  Future<void> setSfxVolume(double value) async {
    sfxVolume = value.clamp(0.0, 1.0);
    await _save();
    notifyListeners();
  }

  Future<void> setBgmTrackIndex(int value) async {
    bgmTrackIndex = value;
    await _save();
    notifyListeners();
  }
}
