import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';

import '../../core/managers/character_manager.dart';
import '../../core/managers/game_state_manager.dart';
import '../../core/managers/skin_manager.dart';
import '../../core/managers/word_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_safe_area.dart';
import '../../core/widgets/compact_character_cheer_card.dart';
import '../../core/widgets/game_attendance_helper.dart';
import '../../core/widgets/game_top_bar.dart';
import '../../core/widgets/heart_gate_helper.dart';
import '../../core/widgets/readable_result_dialog.dart';
import '../../core/widgets/tutorial_intro_overlay.dart';

class AnagramScreen extends StatefulWidget {
  const AnagramScreen({super.key});

  @override
  State<AnagramScreen> createState() => _AnagramScreenState();
}

class _AnagramScreenState extends State<AnagramScreen> {
  final WordRepository _repo = WordRepository.instance;
  static const String _tutorialAnswer = 'STREAM';
  late AnagramRoundData _round;
  final Set<String> _foundCore = {};
  final Set<String> _foundGeneral = {};
  final StringBuffer _input = StringBuffer();
  late List<String> _seedTiles;
  final List<int> _pickedTileIndexes = [];
  int _score = 0;
  int _stage = 1;
  bool _stageLoaded = false;
  bool _dialogOpen = false;
  bool _showTutorialIntro = false;
  int _tutorialStep = 0;
  bool _heartGateScheduled = false;
  static const String _guide = '주어진 글자 조합으로 핵심 단어를 찾고, 추가 단어로 보너스 점수를 얻는 모드입니다.';
  static const String _guideTip = '2~3글자 단어를 먼저 확보하고, 핵심 단어 길이를 늘려가며 조합해 보세요.';
  bool get _isTutorialStage => _stage == 1;

  @override
  void initState() {
    super.initState();
    _round = _buildTutorialRound();
    _seedTiles = _round.seed.split('');
    _pickedTileIndexes.clear();
    _tutorialStep = 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stageLoaded) return;
    _stage = context.read<GameStateManager>().getBestStage('anagram');
    _round = _isTutorialStage ? _buildTutorialRound() : _repo.getAnagramRoundForStage(_stage);
    _seedTiles = _isTutorialStage ? _round.seed.split('') : (_round.seed.split('')..shuffle(Random()));
    _pickedTileIndexes.clear();
    final introSeen = !_isTutorialStage || context.read<GameStateManager>().hasSeenStage1Intro('anagram');
    _showTutorialIntro = _isTutorialStage && !introSeen;
    _tutorialStep = _isTutorialStage ? (_showTutorialIntro ? -1 : 0) : 3;
    _stageLoaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.watch<SkinManager>().currentSkin;
    final state = context.watch<GameStateManager>();
    _scheduleHeartGate(state);
    final char = CharacterManager().getById(state.selectedCharacterId);
    final allCoreFound = _foundCore.length == _round.coreWords.length;
    final hasKorMeaning = _repo.hasKoreanMeaning(_round.seedInfo.korMeaning);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(skin.backgroundPath, fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: Colors.white.withValues(alpha: 0.72))),
          AppSafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    GameTopBar(
                      title: 'ANAGRAM',
                      stage: _stage,
                      state: state,
                      textColor: AppColors.textPrimary,
                    ),
                    if (_isTutorialStage) const SizedBox(height: 8),
                    CompactCharacterCheerCard(
                      character: char,
                      trailing: TextButton(
                        onPressed: () async {
                          if (_isTutorialStage) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('튜토리얼 스테이지에서는 힌트를 사용할 수 없습니다.')),
                            );
                            return;
                          }
                          final result = await state.consumeHint(
                            gameId: 'anagram',
                            baseCost: 2,
                            cooldown: const Duration(seconds: 18),
                          );
                          if (!context.mounted) return;
                          final first = _round.coreWords.first;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result.ok ? 'Hint: core starts with ${first[0]}' : result.message,
                              ),
                            ),
                          );
                        },
                        child: const Text('Hint'),
                      ),
                    ),
                    if (_isTutorialStage && !_showTutorialIntro) ...[
                      const SizedBox(height: 8),
                      _tutorialActionHint(
                        _tutorialStep == 0
                            ? '튜토리얼: STREAM 글자 타일을 눌러 조합을 시작하세요.'
                            : _tutorialStep == 1
                                ? '튜토리얼: 3글자 이상 만든 뒤 STREAM을 완성하세요.'
                                : '튜토리얼: Submit으로 STREAM을 제출하세요.',
                      ),
                    ],
                    const SizedBox(height: 10),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_round.seedInfo.pos} / ${_round.seed.length} letters',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _round.seedInfo.meaning,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (hasKorMeaning) ...[
                            const SizedBox(height: 4),
                            Text(
                              _round.seedInfo.korMeaning,
                              style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
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
                        children: _seedTiles.asMap().entries.map((entry) {
                          final index = entry.key;
                          final ch = entry.value;
                          final disabled = ch.isEmpty;
                          return ElevatedButton(
                            onPressed: disabled
                                ? null
                                : () => _onTapSeedTile(index),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: disabled ? Colors.grey.shade400 : null,
                            ),
                            child: Text(ch, style: const TextStyle(fontWeight: FontWeight.w900)),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                        child: Text(
                          _input.toString().isEmpty ? 'Build word...' : _input.toString(),
                          key: ValueKey('ana-${_input.toString()}'),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              if (_pickedTileIndexes.isNotEmpty) {
                                final text = _input.toString();
                                final lastIndex = _pickedTileIndexes.removeLast();
                                final lastChar = text[text.length - 1];
                                _seedTiles[lastIndex] = lastChar;
                                _input.clear();
                                _input.write(text.substring(0, text.length - 1));
                                _updateTutorialStepFromInput();
                              }
                            }),
                            child: const Text('Back'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              _seedTiles = _isTutorialStage ? _round.seed.split('') : (_round.seed.split('')..shuffle(Random()));
                              _pickedTileIndexes.clear();
                              _input.clear();
                              _updateTutorialStepFromInput();
                            }),
                            child: const Text('Clear'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              side: _isTutorialStage && _tutorialStep == 2
                                  ? const BorderSide(color: Color(0xFFD9480F), width: 2)
                                  : null,
                            ),
                            onPressed: () => _submitWord(state),
                            child: const Text('Submit'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _metric('Core', '${_foundCore.length}/${_round.coreWords.length}', const Color(0xFF2455D6)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _metric(
                            'General',
                            '${_foundGeneral.length}/${_round.generalWords.length}',
                            const Color(0xFF7B2CBF),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _metric('Score', '$_score', AppColors.secondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: _foundWordsPanelHeight(context),
                      child: ListView(
                        children: [
                          const Text('Found Core Words', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _foundCore
                                .map((word) => Chip(label: Text(word), backgroundColor: const Color(0xFFDCEBFF)))
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          const Text('Found General Words', style: TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _foundGeneral
                                .map((word) => Chip(label: Text(word), backgroundColor: const Color(0xFFEFE3FF)))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    if (allCoreFound)
                      ElevatedButton(
                        onPressed: () => _nextRound(state),
                        child: const Text('Core Clear! Next Round'),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_showTutorialIntro)
            Positioned.fill(
              child: TutorialIntroOverlay(
                title: 'ANAGRAM',
                guide: _guide,
                tip: _guideTip,
                onDismiss: _dismissTutorialIntro,
              ),
            ),
        ],
      ),
    );
  }

  double _foundWordsPanelHeight(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    return (viewportHeight * 0.23).clamp(120.0, 220.0);
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

  Future<void> _dismissTutorialIntro() async {
    final state = context.read<GameStateManager>();
    await state.markStage1IntroSeen('anagram');
    if (!mounted) return;
    setState(() {
      _showTutorialIntro = false;
      _tutorialStep = 0;
    });
  }

  Widget _metric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  void _onTapSeedTile(int index) {
    final ch = _seedTiles[index];
    if (ch.isEmpty) return;
    setState(() {
      _input.write(ch);
      _pickedTileIndexes.add(index);
      _seedTiles[index] = '';
      if (_isTutorialStage && _tutorialStep == 0 && _input.isNotEmpty) {
        _tutorialStep = 1;
      }
      if (_isTutorialStage && _tutorialStep == 1 && _input.length >= 3) {
        _tutorialStep = 2;
      }
    });
  }

  void _updateTutorialStepFromInput() {
    if (!_isTutorialStage) return;
    final len = _input.length;
    if (len == 0) {
      _tutorialStep = 0;
      return;
    }
    if (len < 3) {
      _tutorialStep = 1;
      return;
    }
    _tutorialStep = 2;
  }

  Future<void> _submitWord(GameStateManager state) async {
    final candidate = _input.toString().toUpperCase();
    if (_isTutorialStage && _tutorialStep < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('튜토리얼: 먼저 3글자 이상 조합하세요.')),
      );
      return;
    }
    if (_isTutorialStage && candidate != _tutorialAnswer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('튜토리얼: Stage 1은 STREAM 제출로 완료됩니다.')),
      );
      return;
    }
    if (candidate.isEmpty) return;
    _input.clear();
    _pickedTileIndexes.clear();
    _seedTiles = _isTutorialStage ? _round.seed.split('') : (_round.seed.split('')..shuffle(Random()));

    if (_round.coreWords.contains(candidate) && !_foundCore.contains(candidate)) {
      _foundCore.add(candidate);
      _score += 10;
      await state.addStars(3);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Core word found: $candidate (+3 stars)')),
      );
      return;
    }

    if (_round.generalWords.contains(candidate) && !_foundGeneral.contains(candidate)) {
      _foundGeneral.add(candidate);
      _score += 2;
      await state.addStars(1);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('General word: $candidate (+1 star)')),
      );
      return;
    }

    if (_repo.isValidAnagramWordForSeed(seed: _round.seed, candidate: candidate) &&
        !_foundGeneral.contains(candidate) &&
        !_foundCore.contains(candidate)) {
      _foundGeneral.add(candidate);
      _score += 1;
      await state.addStars(1);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bonus valid word: $candidate (+1 star)')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid word for this seed.')),
    );
  }

  Future<void> _nextRound(GameStateManager state) async {
    final clearedRound = _round;
    await state.addStars(5);
    if (!mounted) return;
    await claimAttendanceAndShowDialog(context, state);
    if (!mounted) return;
    _stage += 1;
    await state.setBestStageIfHigher('anagram', _stage);
    if (!mounted) return;
    setState(() {
      _round = _repo.getAnagramRoundForStage(_stage);
      _seedTiles = _round.seed.split('')..shuffle(Random());
      _pickedTileIndexes.clear();
      _foundCore.clear();
      _foundGeneral.clear();
      _input.clear();
      _score = 0;
    });
    await _showResultDialog(
      title: 'Stage Clear',
      seed: clearedRound.seedInfo,
      starsDelta: 5,
    );
  }

  Future<void> _showResultDialog({
    required String title,
    required WordData seed,
    required int starsDelta,
  }) async {
    if (!mounted || _dialogOpen) return;
    _dialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ReadableResultDialog(
          title: title,
          success: true,
          headline: 'Cleared word: ${seed.word}',
          lines: [
            ResultLine(label: 'POS', value: seed.pos),
            ResultLine(label: 'Theme', value: '${seed.themeGroup} / ${seed.themeCategory}'),
            ResultLine(label: 'Meaning', value: seed.meaning),
            if (_repo.hasKoreanMeaning(seed.korMeaning)) ResultLine(label: 'Korean', value: seed.korMeaning),
            ResultLine(label: 'Synonym', value: seed.synonym.isEmpty ? '-' : seed.synonym),
            ResultLine(label: 'Antonym', value: seed.antonym.isEmpty ? '-' : seed.antonym),
            ResultLine(label: 'Reward', value: '+$starsDelta stars', accent: true),
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

  AnagramRoundData _buildTutorialRound() {
    return const AnagramRoundData(
      seedInfo: WordData(
        word: _tutorialAnswer,
        meaning: 'A continuous flow of water or information.',
        korMeaning: '흐름, 시냇물',
        pos: 'Noun',
        difficulty: 1,
      ),
      coreWords: {_tutorialAnswer},
      generalWords: {'TEAM', 'SEAT', 'TAME', 'RATE', 'EAST', 'MEAT', 'TEAR', 'SMART'},
    );
  }
}


