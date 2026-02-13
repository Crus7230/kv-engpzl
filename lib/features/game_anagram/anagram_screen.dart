import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/managers/character_manager.dart';
import '../../core/managers/game_state_manager.dart';
import '../../core/managers/skin_manager.dart';
import '../../core/managers/word_repository.dart';
import '../../core/theme/app_theme.dart';

class AnagramScreen extends StatefulWidget {
  const AnagramScreen({super.key});

  @override
  State<AnagramScreen> createState() => _AnagramScreenState();
}

class _AnagramScreenState extends State<AnagramScreen> {
  final WordRepository _repo = WordRepository.instance;
  late AnagramRoundData _round;
  final Set<String> _foundCore = {};
  final Set<String> _foundGeneral = {};
  final StringBuffer _input = StringBuffer();
  int _score = 0;
  int _stage = 1;
  bool _stageLoaded = false;

  @override
  void initState() {
    super.initState();
    _round = _repo.getAnagramRound();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stageLoaded) return;
    _stage = context.read<GameStateManager>().getBestStage('anagram');
    _stageLoaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.watch<SkinManager>().currentSkin;
    final state = context.watch<GameStateManager>();
    final char = CharacterManager().getById(state.selectedCharacterId);
    final allCoreFound = _foundCore.length == _round.coreWords.length;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(skin.backgroundPath, fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: Colors.white.withValues(alpha: 0.86))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_ios_new)),
                      const Spacer(),
                      const Text('ANAGRAM', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
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
                            '${char.name}: ${char.hints['anagram'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Seed: ${_round.seed}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _round.seedInfo.korMeaning,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _round.seed.split('').map((ch) {
                      return ElevatedButton(
                        onPressed: () => setState(() => _input.write(ch)),
                        child: Text(ch, style: const TextStyle(fontWeight: FontWeight.w900)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      _input.toString().isEmpty ? 'Build word...' : _input.toString(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() {
                            final text = _input.toString();
                            if (text.isNotEmpty) {
                              _input.clear();
                              _input.write(text.substring(0, text.length - 1));
                            }
                          }),
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(_input.clear),
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
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
                        child: _metric('General', '${_foundGeneral.length}', const Color(0xFF7B2CBF)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _metric('Score', '$_score', AppColors.secondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
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
        ],
      ),
    );
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

  Future<void> _submitWord(GameStateManager state) async {
    final candidate = _input.toString().toUpperCase();
    if (candidate.isEmpty) return;
    _input.clear();

    if (_round.coreWords.contains(candidate) && !_foundCore.contains(candidate)) {
      _foundCore.add(candidate);
      _score += 10;
      await state.addStars(3);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Core word found! +3 stars')),
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
        const SnackBar(content: Text('General word bonus +1 star')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Not in round dictionary.')),
    );
  }

  Future<void> _nextRound(GameStateManager state) async {
    await state.addStars(5);
    _stage += 1;
    await state.setBestStageIfHigher('anagram', _stage);
    if (!mounted) return;
    setState(() {
      _round = _repo.getAnagramRound();
      _foundCore.clear();
      _foundGeneral.clear();
      _input.clear();
      _score = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Stage clear reward +5 stars')),
    );
  }
}

