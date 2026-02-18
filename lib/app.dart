import 'package:flutter/material.dart';

import 'core/managers/sound_manager.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class EnglishPuzzleApp extends StatefulWidget {
  const EnglishPuzzleApp({super.key});

  @override
  State<EnglishPuzzleApp> createState() => _EnglishPuzzleAppState();
}

class _EnglishPuzzleAppState extends State<EnglishPuzzleApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    SoundManager.instance.handleAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kavon Eng Puzzle',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
