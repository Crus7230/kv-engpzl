import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/managers/character_manager.dart';
import '../../core/managers/game_state_manager.dart';
import '../../core/managers/skin_manager.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_safe_area.dart';
import '../../core/widgets/game_top_bar.dart';
import '../../core/widgets/readable_result_dialog.dart';
import 'wordle_provider.dart';

class WordleScreen extends StatefulWidget {
  const WordleScreen({super.key});

  @override
  State<WordleScreen> createState() => _WordleScreenState();
}

class _WordleScreenState extends State<WordleScreen> {
  bool _dialogOpen = false;
  final RegExp _hangul = RegExp(r'[\uAC00-\uD7A3]');
  int _tutorialStep = 0;
  int _lastSeenStage = -1;
  bool _isTutorialStage(int stage) => stage == 1;

  bool _hasKoreanMeaning(String text) {
    final value = text.trim();
    if (value.isEmpty) return false;
    if (value.toLowerCase().contains('korean meaning pending')) return false;
    return _hangul.hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<WordleProvider>();
    final skin = context.watch<SkinManager>().currentSkin;
    final gameState = context.watch<GameStateManager>();
    final character = CharacterManager().getById(gameState.selectedCharacterId);
    _syncTutorialState(game);

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
          Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.1))),
          AppSafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: Column(
                children: [
                  GameTopBar(
                    title: 'WORDLE',
                    stage: game.stage,
                    state: gameState,
                    stageLabel: 'STAGE ${game.stage}  -  ${game.badgeLabel}',
                    badgeColor: game.badgeColor,
                  ),
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
          if (_isTutorialStage(game.stage)) _tutorialOverlay(_tutorialCard(game)),
        ],
      ),
    );
  }

  Widget _tutorialOverlay(Widget child) {
    final media = MediaQuery.of(context);
    final compact = media.size.height < 760;
    final preferBottom = compact && _tutorialStep <= 1;
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: preferBottom ? Alignment.bottomCenter : Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              preferBottom ? 0 : media.padding.top + 80,
              12,
              preferBottom ? 12 : 0,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _board(WordleProvider game, GameSkin skin) {
    if (game.isLoading) {
      return const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()));
    }
    final media = MediaQuery.of(context);
    final widthFit = ((media.size.width - 44) / game.wordLength) - 7;
    final estimatedNonBoard = media.size.height < 760 ? 520.0 : 560.0;
    final heightFit = ((media.size.height - estimatedNonBoard) / game.maxRows) - 6;
    final tileSize = min(widthFit, heightFit).clamp(34.0, 58.0);
    final tileFontSize = (tileSize * 0.45).clamp(16.0, 26.0);
    final boardHeight = (tileSize * game.maxRows) + (6 * game.maxRows);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isTutorialStage(game.stage) && _tutorialStep <= 1
              ? const Color(0xFFD9480F)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: SizedBox(
        height: boardHeight,
        child: Column(
        children: List.generate(game.maxRows, (row) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(game.wordLength, (col) {
              final status = game.statusBoard[row][col];
              final text = game.board[row][col];
              final tileColor = _tileColor(status, skin);
              return Container(
                width: tileSize,
                height: tileSize,
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
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 170),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Text(
                    text,
                    key: ValueKey('w-$row-$col-$text-$status'),
                    style: TextStyle(
                      fontSize: tileFontSize,
                      fontWeight: FontWeight.w900,
                      color: status == TileStatus.initial ? skin.textColor : Colors.white,
                    ),
                  ),
                ),
              );
            }),
          );
        }),
        ),
      ),
    );
  }

  Widget _characterHint(CharacterProfile character, WordleProvider game) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
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
              if (_isTutorialStage(game.stage)) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('튜토리얼 스테이지에서는 힌트를 사용할 수 없습니다.')),
                );
                return;
              }
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

  Widget _tutorialCard(WordleProvider game) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB7D3FA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '튜토리얼 - 스테이지 1',
            style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8)),
          ),
          const SizedBox(height: 6),
          Text(
            _tutorialStep == 0
                ? '1단계: 이번 스테이지 정답은 BOOK입니다. 키보드로 입력하세요.'
                : _tutorialStep == 1
                    ? '2단계: ${game.wordLength}칸을 다 채워서 제출 준비를 하세요.'
                    : _tutorialStep == 2
                        ? '3단계: ENTER를 눌러 색상 결과를 확인하세요.'
                        : '완료: Stage 1은 고정 정답 BOOK 튜토리얼입니다.',
            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFD9480F)),
          ),
          const SizedBox(height: 4),
          const Text('1) 초록: 글자와 위치가 모두 맞음'),
          const Text('2) 노랑: 글자는 맞지만 위치가 다름'),
          const Text('3) 회색: 정답에 없는 글자'),
          const Text('4) 튜토리얼에서는 힌트가 비활성화됩니다.'),
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
        final actionWidth = (keyWidth * 2.5).clamp(94.0, 132.0).toDouble();
        final highlightKeys = _isTutorialStage(game.stage) && _tutorialStep <= 1;
        final highlightEnter = _isTutorialStage(game.stage) && _tutorialStep == 2;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (highlightKeys || highlightEnter) ? const Color(0xFFD9480F) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
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
                          onPressed: () => _onTutorialTypeKey(game, key),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: highlightKeys
                                ? const Color(0xFFD9480F)
                                : _keyColor(game.keyboardStates[key]),
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
                _actionKey(
                  'ENTER',
                  actionWidth,
                  keyHeight,
                  () => _submitGuess(game),
                  emphasized: highlightEnter,
                ),
                _actionKey(
                  'DEL',
                  actionWidth,
                  keyHeight,
                  () => game.backspace(),
                  emphasized: false,
                ),
              ],
            ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionKey(String label, double width, double height, VoidCallback onTap, {required bool emphasized}) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        width: width,
        height: height,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            side: emphasized ? const BorderSide(color: Color(0xFFD9480F), width: 2) : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  Future<void> _submitGuess(WordleProvider game) async {
    if (_isTutorialStage(game.stage) && _tutorialStep < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('튜토리얼: 먼저 글자를 입력하세요.')),
      );
      return;
    }
    if (_isTutorialStage(game.stage) && _tutorialStep == 2 && game.currentCol < game.wordLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('튜토리얼: ENTER 전에 줄을 모두 채우세요.')),
      );
      return;
    }
    if (_isTutorialStage(game.stage) && _tutorialStep == 2) {
      setState(() => _tutorialStep = 3);
    }
    final message = await game.submit();
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onTutorialTypeKey(WordleProvider game, String key) {
    if (_isTutorialStage(game.stage) && _tutorialStep == 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('튜토리얼: 이제 ENTER를 누르세요.')),
      );
      return;
    }
    game.typeKey(key);
    if (!_isTutorialStage(game.stage)) return;
    if (_tutorialStep == 0 && game.currentCol > 0) {
      setState(() => _tutorialStep = 1);
      return;
    }
    if (_tutorialStep == 1 && game.currentCol >= game.wordLength) {
      setState(() => _tutorialStep = 2);
    }
  }

  void _syncTutorialState(WordleProvider game) {
    if (_lastSeenStage == game.stage) return;
    _lastSeenStage = game.stage;
    if (_isTutorialStage(game.stage)) {
      _tutorialStep = 0;
    } else {
      _tutorialStep = 3;
    }
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
        return ReadableResultDialog(
          title: success ? 'Stage Clear' : 'Failed',
          success: success,
          headline: 'Answer: ${game.currentWord.word}',
          lines: [
            ResultLine(label: 'POS', value: game.currentWord.pos),
            ResultLine(label: 'Theme', value: '${game.currentWord.themeGroup} / ${game.currentWord.themeCategory}'),
            ResultLine(label: 'Meaning', value: game.currentWord.meaning),
            if (_hasKoreanMeaning(game.currentWord.korMeaning)) ResultLine(label: 'Korean', value: game.currentWord.korMeaning),
            ResultLine(label: 'Synonym', value: game.currentWord.synonym.isEmpty ? '-' : game.currentWord.synonym),
            ResultLine(label: 'Antonym', value: game.currentWord.antonym.isEmpty ? '-' : game.currentWord.antonym),
            ResultLine(label: success ? 'Reward' : 'Penalty', value: success ? '+5 stars' : '-1 heart', accent: true),
          ],
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



