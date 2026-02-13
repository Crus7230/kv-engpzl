import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/managers/character_manager.dart';
import '../../core/managers/game_state_manager.dart';
import '../../core/managers/skin_manager.dart';
import '../../core/theme/app_theme.dart';
import 'wordle_provider.dart';

class WordleScreen extends StatefulWidget {
  const WordleScreen({super.key});

  @override
  State<WordleScreen> createState() => _WordleScreenState();
}

class _WordleScreenState extends State<WordleScreen> {
  bool _dialogOpen = false;

  @override
  Widget build(BuildContext context) {
    final game = context.watch<WordleProvider>();
    final skin = context.watch<SkinManager>().currentSkin;
    final gameState = context.watch<GameStateManager>();
    final character = CharacterManager().getById(gameState.selectedCharacterId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dialogOpen) return;
      if (game.isWon || game.isLost) {
        _dialogOpen = true;
        _showResult(context, game);
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(skin.backgroundPath, fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.15))),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: Column(
                children: [
                  _header(context, game, gameState),
                  const SizedBox(height: 10),
                  _stageBadge(game),
                  const SizedBox(height: 14),
                  _board(game, skin),
                  const SizedBox(height: 12),
                  _characterHint(character, game),
                  const SizedBox(height: 12),
                  _keyboard(game),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, WordleProvider game, GameStateManager state) {
    return Row(
      children: [
        IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        ),
        const Spacer(),
        const Text(
          'WORDLE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Row(
          children: [
            const Icon(Icons.favorite, color: AppColors.error),
            Text(' ${state.hearts}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            const Icon(Icons.star, color: AppColors.secondary),
            Text(' ${state.stars}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }

  Widget _stageBadge(WordleProvider game) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: game.badgeColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'STAGE ${game.stage}  -  ${game.badgeLabel}',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _board(WordleProvider game, GameSkin skin) {
    if (game.isLoading) {
      return const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()));
    }
    return AspectRatio(
      aspectRatio: game.wordLength / 6,
      child: Column(
        children: List.generate(game.maxRows, (row) {
          return Expanded(
            child: Row(
              children: List.generate(game.wordLength, (col) {
                final status = game.statusBoard[row][col];
                final text = game.board[row][col];
                final tileColor = _tileColor(status, skin);
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: tileColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: status == TileStatus.initial
                            ? Colors.white.withValues(alpha: 0.65)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: status == TileStatus.initial ? skin.textColor : Colors.white,
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _characterHint(CharacterProfile character, WordleProvider game) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundImage: AssetImage(character.imagePath)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${character.name}: ${character.hints['wordle'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final hintResult = await context.read<GameStateManager>().consumeHint(
                gameId: 'wordle',
                baseCost: 2,
                cooldown: const Duration(seconds: 20),
              );
              if (!mounted) return;
              final msg = hintResult.ok ? game.applyHint() : hintResult.message;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg)),
              );
            },
            child: const Text('Hint'),
          ),
        ],
      ),
    );
  }

  Widget _keyboard(WordleProvider game) {
    const rows = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final keyWidth = ((width - 48) / 10).clamp(24.0, 38.0).toDouble();
        final keyHeight = (keyWidth * 1.45).clamp(36.0, 52.0).toDouble();
        final actionWidth = (keyWidth * 2.2).clamp(68.0, 100.0).toDouble();
        return Column(
          children: [
            for (final line in rows)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: line.split('').map((key) {
                  return Padding(
                    padding: const EdgeInsets.all(2),
                    child: SizedBox(
                      width: keyWidth,
                      height: keyHeight,
                      child: ElevatedButton(
                        onPressed: () => game.typeKey(key),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _keyColor(game.keyboardStates[key]),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(key, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _actionKey('ENTER', actionWidth, keyHeight, () => _submitGuess(game)),
                _actionKey('DEL', actionWidth, keyHeight, () => game.backspace()),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _actionKey(String label, double width, double height, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        width: width,
        height: height,
        child: ElevatedButton(
          onPressed: onTap,
          child: Text(label),
        ),
      ),
    );
  }

  Future<void> _submitGuess(WordleProvider game) async {
    final message = await game.submit();
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Color _tileColor(TileStatus status, GameSkin skin) {
    switch (status) {
      case TileStatus.correct:
        return AppColors.success;
      case TileStatus.present:
        return AppColors.secondary;
      case TileStatus.absent:
        return const Color(0xFF868E96);
      case TileStatus.initial:
        return Colors.white.withValues(alpha: 0.5);
    }
  }

  Color _keyColor(TileStatus? status) {
    switch (status) {
      case TileStatus.correct:
        return AppColors.success;
      case TileStatus.present:
        return AppColors.secondary;
      case TileStatus.absent:
        return const Color(0xFF868E96);
      default:
        return const Color(0xFF4C6EF5);
    }
  }

  Future<void> _showResult(BuildContext context, WordleProvider game) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final success = game.isWon;
        return AlertDialog(
          title: Text(success ? 'Stage Clear' : 'Failed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Answer: ${game.currentWord.word}'),
              const SizedBox(height: 8),
              Text(game.currentWord.meaning),
              const SizedBox(height: 6),
              Text(game.currentWord.korMeaning),
              const SizedBox(height: 8),
              Text(success ? 'Reward: +5 stars' : 'Penalty: -1 heart'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                this.context.pop();
              },
              child: const Text('Home'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                if (success) {
                  await game.nextStage();
                } else {
                  await game.retryStage();
                }
                _dialogOpen = false;
              },
              child: Text(success ? 'Next' : 'Retry'),
            ),
          ],
        );
      },
    );
    _dialogOpen = false;
  }
}

