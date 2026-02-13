import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/managers/cloud_sync_manager.dart';
import '../../core/managers/game_state_manager.dart';
import '../../core/managers/skin_manager.dart';
import '../../core/managers/word_repository.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _ready = false;
  bool _failed = false;
  double _progress = 0;
  String _status = 'Preparing resources...';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (!mounted) return;
    setState(() {
      _ready = false;
      _failed = false;
      _progress = 0.08;
      _status = 'Loading game data...';
    });

    final startedAt = DateTime.now();
    try {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      setState(() {
        _progress = 0.24;
        _status = 'Loading word lists...';
      });
      await WordRepository.instance.preload();

      if (!mounted) return;
      setState(() {
        _progress = 0.46;
        _status = 'Connecting to server...';
      });

      await CloudSyncManager.instance.init(context.read<GameStateManager>());

      if (!mounted) return;
      setState(() {
        _progress = 0.78;
        _status = 'Sync complete. Finalizing...';
      });
      await Future<void>.delayed(const Duration(milliseconds: 350));

      const minLoadDuration = Duration(milliseconds: 2200);
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < minLoadDuration) {
        await Future<void>.delayed(minLoadDuration - elapsed);
      }
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _ready = true;
        _status = 'Tap to Start';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _ready = true;
        _progress = 1;
        _status = 'Offline mode ready. Tap to Start';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.watch<SkinManager>().currentSkin;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(skin.backgroundPath, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.45)),
          ),
          Center(
            child: GestureDetector(
              onTap: _ready
                  ? () => context.go('/home')
                  : null,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.82,
                constraints: const BoxConstraints(maxWidth: 360),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_stories, size: 72, color: Colors.white),
                    const SizedBox(height: 16),
                    const Text(
                      'Kavon English Games',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: _ready ? 1 : _progress,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4C6EF5)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _failed ? const Color(0xFFFFE8A1) : Colors.white70,
                        fontSize: 15,
                        fontWeight: _ready ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

