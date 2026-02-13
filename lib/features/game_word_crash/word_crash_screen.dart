import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/managers/character_manager.dart';
import '../../core/managers/game_state_manager.dart';
import '../../core/managers/skin_manager.dart';
import '../../core/managers/word_repository.dart';
import '../../core/theme/app_theme.dart';

enum CrashTileKind { letter, bomb, booster }

class CrashTile {
  CrashTile({
    required this.kind,
    required this.value,
  });

  final CrashTileKind kind;
  final String value;

  bool get isLetter => kind == CrashTileKind.letter;
  bool get isBomb => kind == CrashTileKind.bomb;
  bool get isBooster => kind == CrashTileKind.booster;
}

class WordCrashScreen extends StatefulWidget {
  const WordCrashScreen({super.key});

  @override
  State<WordCrashScreen> createState() => _WordCrashScreenState();
}

class _WordCrashScreenState extends State<WordCrashScreen> {
  final WordRepository _repo = WordRepository.instance;
  final Random _random = Random();

  static const int rows = 7;
  static const int cols = 6;
  final List<List<CrashTile>> grid = [];
  final List<Point<int>> selected = [];

  int combo = 0;
  int score = 0;
  int _stage = 1;
  bool _stageLoaded = false;

  @override
  void initState() {
    super.initState();
    _resetGrid();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stageLoaded) return;
    _stage = context.read<GameStateManager>().getBestStage('word_crash');
    _stageLoaded = true;
  }

  void _resetGrid() {
    grid
      ..clear()
      ..addAll(List.generate(rows, (_) => List.generate(cols, (_) => _randomTile())));
    selected.clear();
  }

  CrashTile _randomTile() {
    final roll = _random.nextDouble();
    if (roll < 0.08) {
      return CrashTile(kind: CrashTileKind.bomb, value: 'B');
    }
    if (roll < 0.14) {
      return CrashTile(kind: CrashTileKind.booster, value: 'S');
    }
    return CrashTile(kind: CrashTileKind.letter, value: _randomLetter());
  }

  String _randomLetter() {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    return letters[_random.nextInt(letters.length)];
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.watch<SkinManager>().currentSkin;
    final state = context.watch<GameStateManager>();
    final char = CharacterManager().getById(state.selectedCharacterId);
    final builtWord = _buildSelectedWord();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(skin.backgroundPath, fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.18))),
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
                        'WORD CRASH',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        CircleAvatar(backgroundImage: AssetImage(char.imagePath)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${char.name}: ${char.hints['word_crash'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final result = await state.consumeHint(
                              gameId: 'word_crash',
                              baseCost: 3,
                              cooldown: const Duration(seconds: 20),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.ok
                                      ? 'Hint: use bombs with valid words for bigger clears.'
                                      : result.message,
                                ),
                              ),
                            );
                          },
                          child: const Text('Hint'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _metric('Word', builtWord.isEmpty ? '-' : builtWord)),
                      const SizedBox(width: 8),
                      Expanded(child: _metric('Combo', '$combo')),
                      const SizedBox(width: 8),
                      Expanded(child: _metric('Score', '$score')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: cols / rows,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        itemCount: rows * cols,
                        itemBuilder: (context, index) {
                          final r = index ~/ cols;
                          final c = index % cols;
                          final point = Point(r, c);
                          final tile = grid[r][c];
                          final isPicked = selected.contains(point);
                          return GestureDetector(
                            onTap: () => _pick(point),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              decoration: BoxDecoration(
                                color: isPicked ? AppColors.secondary : _tileColor(tile),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Center(
                                child: Text(
                                  tile.value,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: isPicked ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(selected.clear),
                          child: const Text('Clear Select'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _submit(state),
                          child: const Text('Pop Word'),
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

  Widget _metric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Color _tileColor(CrashTile tile) {
    if (tile.isBomb) return const Color(0xFFFFD8A8);
    if (tile.isBooster) return const Color(0xFFD0EBFF);
    return Colors.white;
  }

  void _pick(Point<int> point) {
    setState(() {
      if (selected.isEmpty) {
        selected.add(point);
        return;
      }
      if (selected.contains(point)) {
        selected.remove(point);
        return;
      }
      final last = selected.last;
      final adjacent = (last.x - point.x).abs() <= 1 && (last.y - point.y).abs() <= 1;
      if (adjacent) {
        selected.add(point);
      }
    });
  }

  String _buildSelectedWord() {
    final letters = selected
        .map((p) => grid[p.x][p.y])
        .where((t) => t.isLetter)
        .map((t) => t.value)
        .join();
    return letters;
  }

  Future<void> _submit(GameStateManager state) async {
    final selectedTiles = selected.map((p) => grid[p.x][p.y]).toList();
    final word = selectedTiles.where((t) => t.isLetter).map((t) => t.value).join();
    final hasBomb = selectedTiles.any((t) => t.isBomb);
    final hasBooster = selectedTiles.any((t) => t.isBooster);

    if (word.length < 3) {
      _show('Select at least 3 letter blocks.');
      return;
    }
    if (!_repo.isCrashWord(word)) {
      combo = 0;
      selected.clear();
      setState(() {});
      _show('Invalid word.');
      return;
    }

    combo += 1;
    var gained = word.length + combo;
    if (hasBooster) gained += 4;
    score += gained;
    await state.addStars(gained ~/ 2);

    final removalSet = <Point<int>>{...selected};
    if (hasBomb) {
      final bombCells = selected.where((p) => grid[p.x][p.y].isBomb).toList();
      for (final bomb in bombCells) {
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            final nr = bomb.x + dr;
            final nc = bomb.y + dc;
            if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
            removalSet.add(Point(nr, nc));
          }
        }
      }
    }

    for (final point in removalSet) {
      grid[point.x][point.y] = CrashTile(kind: CrashTileKind.letter, value: '');
    }

    _collapseGrid();
    selected.clear();

    if (score >= _stage * 35) {
      _stage += 1;
      await state.setBestStageIfHigher('word_crash', _stage);
    }

    if (!mounted) return;
    setState(() {});
    _show('$word popped. +$gained score${hasBomb ? ' (bomb explode)' : ''}');
  }

  void _collapseGrid() {
    for (int c = 0; c < cols; c++) {
      final colValues = <CrashTile>[];
      for (int r = rows - 1; r >= 0; r--) {
        if (grid[r][c].value.isNotEmpty) {
          colValues.add(grid[r][c]);
        }
      }
      while (colValues.length < rows) {
        colValues.add(_randomTile());
      }
      for (int r = rows - 1, i = 0; r >= 0; r--, i++) {
        grid[r][c] = colValues[i];
      }
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
