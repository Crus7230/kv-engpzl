import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/managers/character_manager.dart';
import '../../core/managers/game_state_manager.dart';
import '../../core/managers/skin_manager.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_safe_area.dart';
import '../../core/widgets/compact_character_cheer_card.dart';
import '../../core/widgets/game_attendance_helper.dart';
import '../../core/widgets/game_top_bar.dart';
import '../../core/widgets/heart_gate_helper.dart';
import '../../core/widgets/readable_result_dialog.dart';
import '../../core/widgets/tutorial_intro_overlay.dart';
import 'wordle_provider.dart';

class WordleScreen extends StatefulWidget {
  const WordleScreen({super.key});

  @override
  State<WordleScreen> createState() => _WordleScreenState();
}

class _WordleScreenState extends State<WordleScreen> {
  bool _dialogOpen = false;
  bool _showTutorialIntro = false;
  final RegExp _hangul = RegExp(r'[\uAC00-\uD7A3]');
  int _tutorialStep = 0;
  int _lastSeenStage = -1;
  bool _heartGateScheduled = false;
  static const String _tutorialWarmupGuess = 'RACE';
  static const String _guide = '6번 안에 정답 단어를 맞히는 게임입니다. 색상 피드백으로 위치와 포함 여부를 파악하세요.';
  static const String _guideTip = '초반에는 모음과 자주 쓰는 자음을 섞어 입력하면 정답 후보를 빠르게 줄일 수 있습니다.';
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
    _scheduleHeartGate(gameState);
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
                  if (_isTutorialStage(game.stage) && !_showTutorialIntro && _tutorialStep <= 3) ...[
                    const SizedBox(height: 8),
                    _tutorialActionHint(_tutorialHintText(game)),
                  ],
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
          if (_showTutorialIntro)
            Positioned.fill(
              child: TutorialIntroOverlay(
                title: 'WORDLE',
                guide: _guide,
                tip: _guideTip,
                onDismiss: () => _dismissTutorialIntro(game),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tutorialActionHint(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD9480F), width: 1.6),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFD9480F)),
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
          color: _isTutorialStage(game.stage) && (_tutorialStep == 0 || _tutorialStep == 2)
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
    return CompactCharacterCheerCard(
      character: character,
      trailing: ElevatedButton(
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
        final highlightKeys = _isTutorialStage(game.stage) && (_tutorialStep == 0 || _tutorialStep == 2);
        final highlightEnter = _isTutorialStage(game.stage) && (_tutorialStep == 1 || _tutorialStep == 3);
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
                  () => _onTapBackspace(game),
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
    if (_isTutorialStage(game.stage)) {
      if (_showTutorialIntro) return;
      final expected = _tutorialStep <= 1 ? _tutorialWarmupGuess : game.currentWord.word.toUpperCase();
      final current = game.board[game.currentRow].join().toUpperCase();
      if (_tutorialStep == 0 || _tutorialStep == 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('튜토리얼: $expected 입력을 먼저 완료하세요.')),
        );
        return;
      }
      if (_tutorialStep != 1 && _tutorialStep != 3) {
        return;
      }
      if (game.currentCol < game.wordLength || current != expected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('튜토리얼: $expected 를 정확히 입력한 뒤 ENTER를 누르세요.')),
        );
        return;
      }
    }
    final message = await game.submit();
    if (_isTutorialStage(game.stage) && mounted) {
      if (_tutorialStep == 1 && !game.isWon && !game.isLost) {
        setState(() => _tutorialStep = 2);
      } else if (_tutorialStep == 3) {
        setState(() => _tutorialStep = 4);
      }
    }
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onTutorialTypeKey(WordleProvider game, String key) {
    if (!_isTutorialStage(game.stage)) {
      game.typeKey(key);
      return;
    }
    if (_showTutorialIntro) return;
    if (_tutorialStep == 1 || _tutorialStep == 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('튜토리얼: ENTER를 눌러 다음 단계로 진행하세요.')),
      );
      return;
    }
    if (_tutorialStep != 0 && _tutorialStep != 2) return;
    if (game.currentCol >= game.wordLength) return;
    final expectedWord = _tutorialStep == 0 ? _tutorialWarmupGuess : game.currentWord.word.toUpperCase();
    final expectedChar = expectedWord[game.currentCol];
    if (key != expectedChar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('튜토리얼: 다음 글자는 $expectedChar 입니다.')),
      );
      return;
    }
    game.typeKey(key);
    if (game.currentCol >= game.wordLength) {
      setState(() => _tutorialStep = _tutorialStep == 0 ? 1 : 3);
    }
  }

  void _onTapBackspace(WordleProvider game) {
    game.backspace();
    if (!_isTutorialStage(game.stage)) return;
    if (_showTutorialIntro) return;
    if (_tutorialStep == 1 && game.currentCol < game.wordLength) {
      setState(() => _tutorialStep = 0);
      return;
    }
    if (_tutorialStep == 3 && game.currentCol < game.wordLength) {
      setState(() => _tutorialStep = 2);
    }
  }

  String _tutorialHintText(WordleProvider game) {
    switch (_tutorialStep) {
      case 0:
        return '튜토리얼: $_tutorialWarmupGuess 를 입력해 색상 피드백을 확인하세요.';
      case 1:
        return '튜토리얼: ENTER를 눌러 색상 결과를 확인하세요.';
      case 2:
        return '튜토리얼: 이제 정답 ${game.currentWord.word.toUpperCase()} 를 입력하세요.';
      case 3:
        return '튜토리얼: ENTER로 정답을 제출하세요.';
      default:
        return '튜토리얼 진행 중';
    }
  }

  Future<void> _dismissTutorialIntro(WordleProvider game) async {
    final state = context.read<GameStateManager>();
    await state.markStage1IntroSeen('wordle');
    if (!mounted) return;
    setState(() {
      _showTutorialIntro = false;
      _tutorialStep = _isTutorialStage(game.stage) ? 0 : 4;
    });
  }

  void _syncTutorialState(WordleProvider game) {
    if (_lastSeenStage == game.stage) return;
    _lastSeenStage = game.stage;
    if (_isTutorialStage(game.stage)) {
      final seen = context.read<GameStateManager>().hasSeenStage1Intro('wordle');
      _showTutorialIntro = !seen;
      _tutorialStep = _showTutorialIntro ? -1 : 0;
    } else {
      _showTutorialIntro = false;
      _tutorialStep = 4;
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
    if (game.isWon) {
      if (!context.mounted) return;
      await claimAttendanceAndShowDialog(context, this.context.read<GameStateManager>());
      if (!context.mounted) return;
    }
    bool actionLocked = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final success = game.isWon;
        return StatefulBuilder(
          builder: (context, setDialogState) => ReadableResultDialog(
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
                onPressed: actionLocked
                    ? null
                    : () {
                        setDialogState(() => actionLocked = true);
                        Navigator.pop(context);
                        this.context.pop();
                      },
                child: const Text('Home'),
              ),
              ElevatedButton(
                onPressed: actionLocked
                    ? null
                    : () async {
                        setDialogState(() => actionLocked = true);
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
          ),
        );
      },
    );
    _dialogOpen = false;
  }

  void _scheduleHeartGate(GameStateManager gameState) {
    if (gameState.hasPlayableHeart) return;
    if (_heartGateScheduled) return;
    _heartGateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        if (context.read<GameStateManager>().hasPlayableHeart) return;
        await showNoHeartsDialogAndGoHome(context);
      } finally {
        _heartGateScheduled = false;
      }
    });
  }
}



