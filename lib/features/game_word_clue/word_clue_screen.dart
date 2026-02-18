import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/managers/character_manager.dart';
import '../../core/managers/game_state_manager.dart';
import '../../core/managers/skin_manager.dart';
import '../../core/managers/word_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_safe_area.dart';
import '../../core/widgets/game_top_bar.dart';
import '../../core/widgets/readable_result_dialog.dart';

class WordClueScreen extends StatefulWidget {
  const WordClueScreen({super.key});

  @override
  State<WordClueScreen> createState() => _WordClueScreenState();
}

class _WordClueScreenState extends State<WordClueScreen> {
  final WordRepository _repo = WordRepository.instance;
  static const String _tutorialAnswer = 'KIND';
  late WordData _round;
  late List<String> _availableTiles;
  final List<String> _picked = [];
  bool _solved = false;
  int _stage = 1;
  bool _stageLoaded = false;
  bool _dialogOpen = false;
  int _tutorialStep = 0;
  bool get _isTutorialStage => _stage == 1;

  @override
  void initState() {
    super.initState();
    _loadRound();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stageLoaded) return;
    _stage = context.read<GameStateManager>().getBestStage('word_clue');
    _loadRound();
    _stageLoaded = true;
  }

  void _loadRound() {
    _round = _isTutorialStage ? _buildTutorialRound() : _repo.getWordClueRoundForStage(_stage);
    _availableTiles = _isTutorialStage
        ? _round.word.toUpperCase().split('')
        : (_round.word.toUpperCase().split('')..shuffle(Random()));
    _picked.clear();
    _solved = false;
    _tutorialStep = _isTutorialStage ? 0 : 3;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.watch<SkinManager>().currentSkin;
    final state = context.watch<GameStateManager>();
    final char = CharacterManager().getById(state.selectedCharacterId);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(skin.backgroundPath, fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.16))),
          AppSafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  GameTopBar(title: 'WORD CLUE', stage: _stage, state: state),
                  if (_isTutorialStage) const SizedBox(height: 10),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_round.pos} / ${_round.word.length} letters',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Dictionary definition',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _round.meaning,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_repo.hasKoreanMeaning(_round.korMeaning)) ...[
                          const SizedBox(height: 6),
                          Text(
                            _round.korMeaning,
                            style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(backgroundImage: AssetImage(char.imagePath)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${char.name}: ${char.hints['word_clue'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: _showHint,
                          child: const Text('Hint'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isTutorialStage && _tutorialStep == 1
                            ? const Color(0xFFD9480F)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                          child: Text(
                            _picked.join().padRight(_round.word.length, '_'),
                            key: ValueKey('picked-${_picked.join()}-${_round.word.length}'),
                            style: const TextStyle(letterSpacing: 4, fontSize: 30, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isTutorialStage && _tutorialStep <= 1
                            ? const Color(0xFFD9480F)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: _availableTiles.asMap().entries.map((entry) {
                      final index = entry.key;
                      final ch = entry.value;
                      final disabled = ch.isEmpty || _solved;
                      return ElevatedButton(
                        onPressed: disabled
                            ? null
                            : () async {
                                _pick(index);
                              if (_picked.length == _round.word.length) {
                                  if (_isTutorialStage && _tutorialStep < 2) {
                                    setState(() => _tutorialStep = 2);
                                  }
                                  await _judge();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(56, 56),
                          backgroundColor: disabled ? Colors.grey : AppColors.primary,
                        ),
                        child: Text(ch.isEmpty ? ' ' : ch, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      );
                    }).toList(),
                  )),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _solved ? null : _clearPick,
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _solved ? _loadRound : null,
                          child: const Text('Next Round'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isTutorialStage) _tutorialOverlay(_tutorialCard()),
        ],
      ),
    );
  }

  Widget _tutorialOverlay(Widget child) {
    return Positioned(
      top: 84,
      left: 12,
      right: 12,
      child: IgnorePointer(child: child),
    );
  }

  void _pick(int index) {
    if (_isTutorialStage && _tutorialStep >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('?쒗넗由ъ뼹: 寃곌낵 ?뺤씤 ?꾩뿉???낅젰?????놁뒿?덈떎.')),
      );
      return;
    }
    setState(() {
      if (_isTutorialStage) {
        final answer = _round.word.toUpperCase();
        final expected = answer[_picked.length];
        final tapped = _availableTiles[index];
        if (tapped != expected) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('?쒗넗由ъ뼹: ?ㅼ쓬 湲?먮뒗 $expected ?낅땲??')),
          );
          return;
        }
      }
      _picked.add(_availableTiles[index]);
      _availableTiles[index] = '';
      if (_isTutorialStage && _tutorialStep == 0 && _picked.isNotEmpty) {
        _tutorialStep = 1;
      }
    });
  }

  void _clearPick() {
    setState(() {
      _availableTiles = _isTutorialStage
          ? _round.word.toUpperCase().split('')
          : (_round.word.toUpperCase().split('')..shuffle(Random()));
      _picked.clear();
      if (_isTutorialStage) {
        _tutorialStep = 0;
      }
    });
  }

  Future<void> _judge() async {
    final answer = _picked.join();
    final state = context.read<GameStateManager>();
    if (answer == _round.word.toUpperCase()) {
      _solved = true;
      await state.addStars(4);
      _stage += 1;
      await state.setBestStageIfHigher('word_clue', _stage);
      if (!mounted) return;
      setState(() {});
      await _showResultDialog(
        success: true,
        title: 'Correct',
        body: 'Answer: ${_round.word}',
        wordData: _round,
        starsDelta: 4,
        heartDelta: 0,
      );
      return;
    }
    await state.consumeHeart();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wrong answer. -1 heart')),
    );
    _clearPick();
  }

  Future<void> _showHint() async {
    if (_isTutorialStage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('?쒗넗由ъ뼹 ?ㅽ뀒?댁??먯꽌???뚰듃瑜??ъ슜?????놁뒿?덈떎.')),
      );
      return;
    }
    final state = context.read<GameStateManager>();
    final result = await state.consumeHint(
      gameId: 'word_clue',
      baseCost: 2,
      cooldown: const Duration(seconds: 15),
    );
    if (!mounted) return;
    final msg = result.ok ? 'Hint: first letter is ${_round.word[0]}' : result.message;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _tutorialCard() {
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
                ? '1단계: 고정 정답 KIND를 순서대로 조합해 시작하세요.'
                : _tutorialStep == 1
                    ? '2단계: 칸을 모두 채우면 자동으로 정답 판정이 진행됩니다.'
                    : _tutorialStep == 2
                        ? '3단계: 결과를 확인하세요.'
                        : '완료: Stage 1은 KIND 고정 튜토리얼입니다.',
            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFD9480F)),
          ),
          const SizedBox(height: 4),
          const Text('1) Stage 1은 단어/타일 순서가 미리 세팅되어 있습니다.'),
          const Text('2) 잘못된 순서는 하트 차감 없이 안내됩니다.'),
          const Text('3) 정답 흐름을 익힌 뒤 일반 라운드로 넘어갑니다.'),
          const Text('4) 튜토리얼에서는 힌트가 비활성화됩니다.'),
        ],
      ),
    );
  }

  Future<void> _showResultDialog({
    required bool success,
    required String title,
    required String body,
    WordData? wordData,
    required int starsDelta,
    required int heartDelta,
  }) async {
    if (!mounted || _dialogOpen) return;
    _dialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ReadableResultDialog(
          title: title,
          success: success,
          headline: body,
          lines: [
            if (wordData != null) ...[
              ResultLine(label: 'POS', value: wordData.pos),
              ResultLine(label: 'Theme', value: '${wordData.themeGroup} / ${wordData.themeCategory}'),
              ResultLine(label: 'Meaning', value: wordData.meaning),
              if (_repo.hasKoreanMeaning(wordData.korMeaning)) ResultLine(label: 'Korean', value: wordData.korMeaning),
              ResultLine(label: 'Synonym', value: wordData.synonym.isEmpty ? '-' : wordData.synonym),
              ResultLine(label: 'Antonym', value: wordData.antonym.isEmpty ? '-' : wordData.antonym),
            ],
            ResultLine(label: 'Stars', value: '${starsDelta >= 0 ? '+' : ''}$starsDelta', accent: true),
            ResultLine(label: 'Hearts', value: '${heartDelta >= 0 ? '+' : ''}$heartDelta', accent: true),
          ],
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    _dialogOpen = false;
  }

  WordData _buildTutorialRound() {
    return const WordData(
      word: _tutorialAnswer,
      meaning: 'Having a friendly, generous, and considerate nature.',
      korMeaning: '친절한',
      pos: 'Adjective',
      difficulty: 1,
      themeGroup: 'Word',
      themeCategory: 'Tutorial',
    );
  }
}



