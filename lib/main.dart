import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/managers/game_state_manager.dart';
import 'core/managers/skin_manager.dart';
import 'core/managers/settings_manager.dart';
import 'core/managers/sound_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final gameState = GameStateManager();
  await gameState.init();

  final skinManager = SkinManager();
  await skinManager.init();
  final settingsManager = SettingsManager();
  await settingsManager.init();
  SettingsManagerHolder.settings = settingsManager;
  await SoundManager.instance.applySettings();
  if (settingsManager.bgmOn) {
    await SoundManager.instance.playBgm(settingsManager.bgmTrackIndex);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: gameState),
        ChangeNotifierProvider.value(value: skinManager),
        ChangeNotifierProvider.value(value: settingsManager),
      ],
      child: const EnglishPuzzleApp(),
    ),
  );
}
