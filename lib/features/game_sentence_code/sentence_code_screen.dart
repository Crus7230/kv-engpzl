import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/managers/character_manager.dart';
import '../../core/managers/game_state_manager.dart';
import '../../core/managers/sentence_code_repository.dart';
import '../../core/managers/skin_manager.dart';
import '../../core/widgets/app_safe_area.dart';
import '../../core/widgets/game_hud.dart';

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
  int _stage = 1;
  late SentenceCodeLevel _level;
  late String _sentenceUpper;
  Map<String, int> _letterNumberMap = const {};

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
    final level = _repo.getLevelForStage(stage);
    final upper = level.sentence.toUpperCase();
    setState(() {
      _stage = max(1, stage);
      _level = level;
      _sentenceUpper = upper;
      _revealedLetters.clear();
      _hiddenHintOpened = false;
      _letterNumberMap = _buildLetterNumberMap(upper);
      _loading = false;
    });
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
          Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.14))),
          AppSafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                            ),
                            const Spacer(),
                            const Text(
                              'SENTENCE CODE',
                              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                            ),
                            const Spacer(),
                            GameHud(state: state),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D4ED8).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            'STAGE $_stage',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _characterHintCard(char),
                        const SizedBox(height: 10),
                        _sentenceCard(),
                        const SizedBox(height: 10),
                        _hintsCard(),
                        const SizedBox(height: 10),
                        _keyboard(),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _characterHintCard(CharacterProfile char) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundImage: AssetImage(char.imagePath)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${char.name}: ${char.hints['sentence_code'] ?? 'Think in chunks, not single letters.'}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: _useHint,
            child: const Text('Hint'),
          ),
        ],
      ),
    );
  }

  Widget _sentenceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: _sentenceUpper.split('').map((ch) {
          if (_letterPattern.hasMatch(ch)) {
            final revealed = _revealedLetters.contains(ch);
            final text = revealed ? ch : '${_letterNumberMap[ch] ?? ''}';
            return Container(
              width: 30,
              height: 34,
              decoration: BoxDecoration(
                color: revealed ? const Color(0xFFDDEBFF) : const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              alignment: Alignment.center,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: revealed ? 18 : 13,
                  fontWeight: FontWeight.w800,
                  color: revealed ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
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

  Widget _hintsCard() {
    final hints = <SentenceHintData>[
      ..._level.visibleHints,
      if (_hiddenHintOpened && _level.hiddenHint != null) _level.hiddenHint!,
    ];
    return Expanded(
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
                Text(
                  _maskHintWord(hint.word),
                  style: const TextStyle(letterSpacing: 2.3, fontWeight: FontWeight.w800),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _keyboard() {
    final letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
    return Wrap(
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
    );
  }

  Future<void> _onTapLetter(String letter) async {
    if (_revealedLetters.contains(letter)) return;
    final state = context.read<GameStateManager>();
    if (_sentenceUpper.contains(letter)) {
      setState(() {
        _revealedLetters.add(letter);
      });
      if (_isSolved()) {
        await _handleSolve(state);
      }
      return;
    }
    await state.consumeHeart();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wrong letter. -1 heart')),
    );
  }

  Future<void> _useHint() async {
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
    _stage += 1;
    await state.setBestStageIfHigher('sentence_code', _stage);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Stage Clear'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_sentenceUpper),
              const SizedBox(height: 8),
              if (_level.translation.trim().isNotEmpty) Text(_level.translation),
              if (_level.similarProverb.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Related: ${_level.similarProverb}'),
              ],
              const SizedBox(height: 8),
              const Text('+10 stars'),
            ],
          ),
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

  String _maskHintWord(String word) {
    final upper = word.toUpperCase();
    final chars = upper.split('');
    return chars.map((ch) {
      if (!_letterPattern.hasMatch(ch)) return ch;
      return _revealedLetters.contains(ch) ? ch : '_';
    }).join(' ');
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
}
