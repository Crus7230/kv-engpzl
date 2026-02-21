import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/managers/character_manager.dart';
import '../../core/managers/game_state_manager.dart';
import '../../core/managers/sentence_code_repository.dart';
import '../../core/managers/skin_manager.dart';
import '../../core/widgets/app_safe_area.dart';
import '../../core/widgets/compact_character_cheer_card.dart';
import '../../core/widgets/game_attendance_helper.dart';
import '../../core/widgets/game_top_bar.dart';
import '../../core/widgets/heart_gate_helper.dart';
import '../../core/widgets/readable_result_dialog.dart';
import '../../core/widgets/tutorial_intro_overlay.dart';

class SentenceCodeScreen extends StatefulWidget {
  const SentenceCodeScreen({super.key});

  @override
  State<SentenceCodeScreen> createState() => _SentenceCodeScreenState();
}

class _SentenceCodeScreenState extends State<SentenceCodeScreen> {
  final SentenceCodeRepository _repo = SentenceCodeRepository.instance;
  final Set<String> _revealedLetters = <String>{};
  final RegExp _letterPattern = RegExp(r'[A-Z]');

  bool _loading = true;
  bool _stageLoaded = false;
  bool _hiddenHintOpened = false;
  bool _dialogOpen = false;
  bool _showTutorialIntro = false;
  bool _heartGateScheduled = false;
  int _stage = 1;
  int? _selectedNumber;
  late SentenceCodeLevel _level;
  late String _sentenceUpper;
  Map<String, int> _letterNumberMap = const {};
  static const String _guide = '문장 속 알파벳이 번호로 암호화되어 있습니다. 단서 단어를 활용해 전체 문장을 복원하세요.';
  static const String _guideTip = '반복되는 번호를 먼저 찾아 같은 알파벳을 추론하면 문장 복원 속도가 크게 올라갑니다.';

  bool get _isTutorialStage => _stage == 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stageLoaded) return;
    _stage = context.read<GameStateManager>().getBestStage('sentence_code');
    _loadLevelForStage(_stage);
    _stageLoaded = true;
  }

  Future<void> _loadLevelForStage(int stage) async {
    setState(() => _loading = true);
    await _repo.preload();
    if (!mounted) return;
    final normalizedStage = max(1, stage);
    final level = _repo.getLevelForStage(normalizedStage);
    final upper = level.sentence.toUpperCase();
    final presetLetters = _buildTutorialPresetLetters(upper, normalizedStage == 1);
    final introSeen = context.read<GameStateManager>().hasSeenStage1Intro('sentence_code');
    setState(() {
      _stage = normalizedStage;
      _level = level;
      _sentenceUpper = upper;
      _revealedLetters.clear();
      _revealedLetters.addAll(presetLetters);
      _hiddenHintOpened = false;
      _selectedNumber = null;
      _letterNumberMap = _buildLetterNumberMap(upper);
      _showTutorialIntro = normalizedStage == 1 && !introSeen;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.watch<SkinManager>().currentSkin;
    final state = context.watch<GameStateManager>();
    _scheduleHeartGate(state);
    final char = CharacterManager().getById(state.selectedCharacterId);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(skin.backgroundPath, fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.14))),
          AppSafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          GameTopBar(title: 'SENTENCE CODE', stage: _stage, state: state),
                          const SizedBox(height: 10),
                          _characterHintCard(char),
                          if (_isTutorialStage && !_showTutorialIntro) ...[
                            const SizedBox(height: 8),
                            _tutorialActionHint(
                              _selectedNumber == null
                                  ? '튜토리얼: 숫자 칸을 선택해 ${_tutorialHintWord() ?? '힌트 단어'}를 먼저 완성하세요.'
                                  : '튜토리얼: 아래 키보드에서 선택한 번호의 알파벳을 맞추세요.',
                            ),
                          ],
                          const SizedBox(height: 10),
                          _sentenceCard(),
                          if (_selectedNumber != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Selected code: $_selectedNumber',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                            ),
                          ],
                          const SizedBox(height: 10),
                          _hintsCard(height: _hintsCardHeight(context)),
                          const SizedBox(height: 10),
                          _keyboard(),
                        ],
                      ),
                    ),
            ),
          ),
          if (_showTutorialIntro)
            Positioned.fill(
              child: TutorialIntroOverlay(
                title: 'SENTENCE CODE',
                guide: _guide,
                tip: _guideTip,
                onDismiss: _dismissTutorialIntro,
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

  Future<void> _dismissTutorialIntro() async {
    final state = context.read<GameStateManager>();
    await state.markStage1IntroSeen('sentence_code');
    if (!mounted) return;
    setState(() => _showTutorialIntro = false);
  }

  Widget _characterHintCard(CharacterProfile char) {
    return CompactCharacterCheerCard(
      character: char,
      trailing: TextButton(onPressed: _useHint, child: const Text('Hint')),
    );
  }

  Widget _sentenceCard() {
    final highlight = _isTutorialStage && _selectedNumber == null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? const Color(0xFFD9480F) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: _sentenceUpper.split('').map((ch) {
          if (_letterPattern.hasMatch(ch)) {
            final revealed = _revealedLetters.contains(ch);
            final number = _letterNumberMap[ch];
            final text = revealed ? ch : '${number ?? ''}';
            final selected = !revealed && number != null && number == _selectedNumber;

            return GestureDetector(
              onTap: revealed || number == null
                  ? null
                  : () => _onSelectHintNumber(number),
              child: Container(
                width: 30,
                height: 34,
                decoration: BoxDecoration(
                  color: revealed
                      ? const Color(0xFFDDEBFF)
                      : (selected ? const Color(0xFFFFF3BF) : const Color(0xFFF1F3F5)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selected ? const Color(0xFFD9480F) : const Color(0xFFCBD5E1),
                    width: selected ? 1.7 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: revealed ? 18 : 13,
                    fontWeight: FontWeight.w800,
                    color: revealed
                        ? const Color(0xFF1D4ED8)
                        : (selected ? const Color(0xFFD9480F) : const Color(0xFF475569)),
                  ),
                ),
              ),
            );
          }

          if (ch == ' ') {
            return const SizedBox(width: 10, height: 34);
          }

          return SizedBox(
            width: 16,
            height: 34,
            child: Center(
              child: Text(
                ch,
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF475569)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  double _hintsCardHeight(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    return (viewportHeight * 0.26).clamp(140.0, 220.0);
  }

  Widget _hintsCard({required double height}) {
    final hints = <SentenceHintData>[
      ..._level.visibleHints,
      if (_hiddenHintOpened && _level.hiddenHint != null) _level.hiddenHint!,
    ];

    return SizedBox(
      height: height,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListView.separated(
          itemCount: hints.length + (_hiddenHintOpened || _level.hiddenHint == null ? 0 : 1),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (!_hiddenHintOpened && _level.hiddenHint != null && index == hints.length) {
              return const Text(
                'Hidden clue is locked. Use Hint once more to reveal it.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              );
            }

            final hint = hints[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hint.description,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                _buildHintWordTokens(hint.word),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _keyboard() {
    final letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
    final highlight = _isTutorialStage && _selectedNumber != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight ? const Color(0xFFD9480F) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: letters.map((letter) {
        final used = _revealedLetters.contains(letter);
        return SizedBox(
          width: 36,
          height: 40,
          child: ElevatedButton(
            onPressed: used ? null : () => _onTapLetter(letter),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: used ? Colors.grey.shade500 : const Color(0xFF1D4ED8),
            ),
            child: Text(letter, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        );
      }).toList(),
    ));
  }

  Future<void> _onTapLetter(String letter) async {
    if (_revealedLetters.contains(letter)) return;

    final selectedNumber = _selectedNumber;
    if (selectedNumber == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 숫자 칸을 선택하세요.')),
      );
      return;
    }

    if (_isTutorialStage) {
      final required = _nextRequiredNumber();
      if (required != null && selectedNumber != required) {
        _showTutorialOrderMessage(required);
        return;
      }
    }

    final state = context.read<GameStateManager>();
    final matched = _letterNumberMap.entries.where((e) => e.value == selectedNumber).toList(growable: false);

    if (matched.isNotEmpty && matched.first.key == letter) {
      setState(() {
        _revealedLetters.add(letter);
        _selectedNumber = null;
      });
      if (_isSolved()) {
        await _handleSolve(state);
      }
      return;
    }

    if (_isTutorialStage) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('튜토리얼: 힌트 단어를 먼저 맞춰보세요.')),
      );
      return;
    }
    await state.consumeHeart();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wrong letter. -1 heart')),
    );
  }

  Future<void> _useHint() async {
    if (_isTutorialStage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('튜토리얼 스테이지에서는 힌트를 사용할 수 없습니다.')),
      );
      return;
    }

    final state = context.read<GameStateManager>();
    final result = await state.consumeHint(
      gameId: 'sentence_code',
      baseCost: 2,
      cooldown: const Duration(seconds: 20),
    );
    if (!mounted) return;

    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }

    if (!_hiddenHintOpened && _level.hiddenHint != null) {
      setState(() => _hiddenHintOpened = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hidden clue revealed.')),
      );
      return;
    }

    final next = _nextUnrevealedLetter();
    if (next == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unrevealed letters left.')),
      );
      return;
    }

    setState(() => _revealedLetters.add(next));
    if (_isSolved()) {
      await _handleSolve(state);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Hint used. Letter revealed: $next')),
    );
  }

  Future<void> _handleSolve(GameStateManager state) async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    await state.addStars(10);
    if (!mounted) return;
    await claimAttendanceAndShowDialog(context, state);
    if (!mounted) return;
    _stage += 1;
    await state.setBestStageIfHigher('sentence_code', _stage);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ReadableResultDialog(
          title: 'Stage Clear',
          success: true,
          headline: _sentenceUpper,
          lines: [
            if (_level.translation.trim().isNotEmpty) ResultLine(label: 'Translation', value: _level.translation),
            if (_level.similarProverb.trim().isNotEmpty) ResultLine(label: 'Related', value: _level.similarProverb),
            const ResultLine(label: 'Reward', value: '+10 stars', accent: true),
          ],
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Next'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    await _loadLevelForStage(_stage);
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

  bool _isSolved() {
    for (final ch in _sentenceUpper.split('')) {
      if (_letterPattern.hasMatch(ch) && !_revealedLetters.contains(ch)) {
        return false;
      }
    }
    return true;
  }

  String? _nextUnrevealedLetter() {
    for (final ch in _sentenceUpper.split('')) {
      if (_letterPattern.hasMatch(ch) && !_revealedLetters.contains(ch)) {
        return ch;
      }
    }
    return null;
  }

  int? _nextRequiredNumber() {
    final tutorialHintWord = _tutorialHintWord();
    if (tutorialHintWord != null) {
      for (final ch in tutorialHintWord.split('')) {
        if (!_letterPattern.hasMatch(ch)) continue;
        if (_revealedLetters.contains(ch)) continue;
        final number = _letterNumberMap[ch];
        if (number != null) return number;
      }
    }
    for (final ch in _sentenceUpper.split('')) {
      if (!_letterPattern.hasMatch(ch)) continue;
      if (_revealedLetters.contains(ch)) continue;
      return _letterNumberMap[ch];
    }
    return null;
  }

  void _showTutorialOrderMessage(int required) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('튜토리얼: 숫자 $required 칸부터 선택하세요.')),
    );
  }

  Widget _buildHintWordTokens(String word) {
    final upper = word.toUpperCase();
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: upper.split('').map((ch) {
        if (!_letterPattern.hasMatch(ch)) {
          return Container(
            width: 24,
            height: 30,
            alignment: Alignment.center,
            child: Text(
              ch,
              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF475569)),
            ),
          );
        }
        final revealed = _revealedLetters.contains(ch);
        final number = _letterNumberMap[ch];
        final selectable = !revealed && number != null;
        final selected = selectable && number == _selectedNumber;
        return GestureDetector(
          onTap: selectable ? () => _onSelectHintNumber(number!) : null,
          child: Container(
            width: 30,
            height: 34,
            decoration: BoxDecoration(
              color: revealed
                  ? const Color(0xFFDDEBFF)
                  : (selected ? const Color(0xFFFFF3BF) : const Color(0xFFF1F3F5)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected ? const Color(0xFFD9480F) : const Color(0xFFCBD5E1),
                width: selected ? 1.7 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              revealed ? ch : '${number ?? '?'}',
              style: TextStyle(
                fontSize: revealed ? 18 : 12,
                fontWeight: FontWeight.w800,
                color: revealed
                    ? const Color(0xFF1D4ED8)
                    : (selected ? const Color(0xFFD9480F) : const Color(0xFF475569)),
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  void _onSelectHintNumber(int number) {
    if (_isTutorialStage) {
      final required = _nextRequiredNumber();
      if (required != null && number != required) {
        _showTutorialOrderMessage(required);
        return;
      }
    }
    setState(() => _selectedNumber = number);
  }

  Map<String, int> _buildLetterNumberMap(String sentence) {
    final map = <String, int>{};
    var index = 1;
    for (final ch in sentence.split('')) {
      if (!_letterPattern.hasMatch(ch)) continue;
      if (map.containsKey(ch)) continue;
      map[ch] = index;
      index += 1;
    }
    return map;
  }

  Set<String> _buildTutorialPresetLetters(String sentence, bool isTutorialStage) {
    if (!isTutorialStage) return const <String>{};
    final preset = <String>{};
    for (final ch in sentence.split('')) {
      if (!_letterPattern.hasMatch(ch)) continue;
      preset.add(ch);
      if (preset.length >= 2) break;
    }
    return preset;
  }

  String? _tutorialHintWord() {
    if (!_isTutorialStage) return null;
    for (final hint in _level.visibleHints) {
      final word = hint.word.toUpperCase();
      if (word != 'ELEPHANT') continue;
      final letters = word.split('').where((ch) => _letterPattern.hasMatch(ch)).toSet();
      if (letters.isEmpty) continue;
      final allMappable = letters.every((ch) => _letterNumberMap.containsKey(ch));
      if (allMappable) return word;
    }
    for (final hint in _level.visibleHints) {
      final word = hint.word.toUpperCase();
      if (word.isEmpty) continue;
      final letters = word.split('').where((ch) => _letterPattern.hasMatch(ch)).toSet();
      if (letters.isEmpty) continue;
      final allMappable = letters.every((ch) => _letterNumberMap.containsKey(ch));
      if (allMappable) return word;
    }
    return null;
  }
}

