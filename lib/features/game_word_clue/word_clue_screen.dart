import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/managers/character_manager.dart';
import '../../core/managers/game_state_manager.dart';
import '../../core/managers/skin_manager.dart';
import '../../core/managers/word_repository.dart';
import '../../core/theme/app_theme.dart';

class WordClueScreen extends StatefulWidget {
  const WordClueScreen({super.key});

  @override
  State<WordClueScreen> createState() => _WordClueScreenState();
}

class _WordClueScreenState extends State<WordClueScreen> {
  final WordRepository _repo = WordRepository.instance;
  late WordData _round;
  late List<String> _availableTiles;
  final List<String> _picked = [];
  bool _solved = false;
  int _stage = 1;
  bool _stageLoaded = false;

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
    _stageLoaded = true;
  }

  void _loadRound() {
    _round = _repo.getWordClueRound();
    _availableTiles = _round.word.toUpperCase().split('')..shuffle(Random());
    _picked.clear();
    _solved = false;
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
          Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.25))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      ),
                      const Spacer(),
                      const Text(
                        'WORD CLUE',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_round.pos} / ${_round.word.length} letters',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                        ),
                        const SizedBox(height: 8),
                        Text(_round.meaning, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(_round.korMeaning, style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        _picked.join().padRight(_round.word.length, '_'),
                        style: const TextStyle(letterSpacing: 4, fontSize: 30, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
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
                  ),
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
                          onPressed: _loadRound,
                          child: const Text('Next Round'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pick(int index) {
    setState(() {
      _picked.add(_availableTiles[index]);
      _availableTiles[index] = '';
    });
  }

  void _clearPick() {
    setState(() {
      _availableTiles = _round.word.toUpperCase().split('')..shuffle(Random());
      _picked.clear();
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Correct! +4 stars')));
      setState(() {});
      return;
    }
    await state.consumeHeart();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Wrong answer. -1 heart (answer: ${_round.word})')),
    );
    _clearPick();
  }

  Future<void> _showHint() async {
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
}


