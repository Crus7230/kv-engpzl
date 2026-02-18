import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/managers/character_manager.dart';
import '../../core/managers/game_state_manager.dart';
import '../../core/managers/skin_manager.dart';
import '../../core/managers/word_repository.dart';
import '../../core/widgets/app_safe_area.dart';
import '../../core/widgets/game_top_bar.dart';
import '../../core/widgets/readable_result_dialog.dart';

enum CrashTileKind { letter, bomb, booster, blocker }

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
  bool get isBlocker => kind == CrashTileKind.blocker;
}

class CrashStageGoal {
  const CrashStageGoal({
    required this.targetWords,
    required this.injectCount,
    required this.maxWordLength,
    required this.bombRate,
    required this.boosterRate,
    required this.blockerRate,
    required this.missLimitBeforeHeart,
  });

  final int targetWords;
  final int injectCount;
  final int maxWordLength;
  final double bombRate;
  final double boosterRate;
  final double blockerRate;
  final int missLimitBeforeHeart;
}

class WordCrashScreen extends StatefulWidget {
  const WordCrashScreen({super.key});

  @override
  State<WordCrashScreen> createState() => _WordCrashScreenState();
}

class _WordCrashScreenState extends State<WordCrashScreen> {
  final WordRepository _repo = WordRepository.instance;
  final Random _random = Random();
  static const String _specialWildcard = '*';
  static const String _tutorialTargetWord = 'GAME';

  static const int rows = 7;
  static const int cols = 6;
  final List<List<CrashTile>> grid = [];
  final List<Point<int>> selected = [];
  final Set<Point<int>> _poppingCells = <Point<int>>{};

  bool _stageLoaded = false;
  bool _dialogOpen = false;

  int _stage = 1;
  int _combo = 0;
  int _wordsClearedInStage = 0;
  int _mistakesInStage = 0;
  late CrashStageGoal _goal;
  int _tutorialStep = 0;
  bool get _isTutorialStage => _stage == 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stageLoaded) return;
    _setupStage(context.read<GameStateManager>().getBestStage('word_crash'));
    _stageLoaded = true;
  }

  CrashStageGoal _goalForStage(int stage) {
    final normalized = stage.clamp(1, 999);
    final targetWords = min(9, 3 + ((normalized - 1) ~/ 2));
    final injectCount = max(1, 4 - ((normalized - 1) ~/ 4));
    final maxWordLength = min(7, 4 + ((normalized - 1) ~/ 2));
    final bombRate = (0.05 + (normalized * 0.002)).clamp(0.05, 0.11);
    final boosterRate = (0.015 + (normalized * 0.0006)).clamp(0.015, 0.045);
    final blockerRate = (normalized % 4 == 0 || normalized % 7 == 0) ? 0.08 : 0.0;
    final missLimitBeforeHeart = normalized <= 3 ? 2 : 1;
    return CrashStageGoal(
      targetWords: targetWords,
      injectCount: injectCount,
      maxWordLength: maxWordLength,
      bombRate: bombRate,
      boosterRate: boosterRate,
      blockerRate: blockerRate,
      missLimitBeforeHeart: missLimitBeforeHeart,
    );
  }

  void _setupStage(int stage) {
    _stage = stage;
    _goal = _isTutorialStage
        ? const CrashStageGoal(
            targetWords: 1,
            injectCount: 0,
            maxWordLength: 4,
            bombRate: 0,
            boosterRate: 0,
            blockerRate: 0,
            missLimitBeforeHeart: 99,
          )
        : _goalForStage(stage);
    _combo = 0;
    _wordsClearedInStage = 0;
    _mistakesInStage = 0;
    _tutorialStep = _isTutorialStage ? 0 : 3;
    _resetGrid();
  }

  void _resetGrid() {
    if (_isTutorialStage) {
      _resetTutorialGrid();
      return;
    }
    grid
      ..clear()
      ..addAll(List.generate(rows, (_) => List.generate(cols, (_) => _randomTile(allowBlocker: true))));
    _injectPlayableWords(count: _goal.injectCount, maxLength: _goal.maxWordLength);
    selected.clear();
    _poppingCells.clear();
  }

  void _resetTutorialGrid() {
    const fixed = <String>[
      'GAMERT',
      'PLANED',
      'SMILES',
      'TREEST',
      'NOTESR',
      'WORLDA',
      'QUIZON',
    ];
    grid
      ..clear()
      ..addAll(
        List.generate(
          rows,
          (r) => List.generate(
            cols,
            (c) => CrashTile(kind: CrashTileKind.letter, value: fixed[r][c]),
          ),
        ),
      );
    selected.clear();
    _poppingCells.clear();
  }

  CrashTile _randomTile({required bool allowBlocker}) {
    final roll = _random.nextDouble();
    if (allowBlocker && _goal.blockerRate > 0 && roll < _goal.blockerRate) {
      return CrashTile(kind: CrashTileKind.blocker, value: 'X');
    }
    if (roll < _goal.bombRate + _goal.blockerRate) {
      return CrashTile(kind: CrashTileKind.bomb, value: '!');
    }
    if (roll < _goal.bombRate + _goal.boosterRate + _goal.blockerRate) {
      return CrashTile(kind: CrashTileKind.booster, value: '*');
    }
    return CrashTile(kind: CrashTileKind.letter, value: _randomLetter());
  }

  String _randomLetter() {
    const weighted = 'EEEEEEEEAAAAAAAARRRRRRIIIIIIOOOOONNNNNNTTTTTLLLLSSSSUUDDGBCMPFHVWYKJXQZ';
    return weighted[_random.nextInt(weighted.length)];
  }

  void _injectPlayableWords({required int count, required int maxLength}) {
    final candidates = _repo.getCrashWords(minLength: 3, maxLength: maxLength);
    if (candidates.isEmpty) return;
    final directions = <Point<int>>[
      const Point(0, 1),
      const Point(1, 0),
      const Point(1, 1),
      const Point(1, -1),
      const Point(0, -1),
      const Point(-1, 0),
      const Point(-1, -1),
      const Point(-1, 1),
    ];

    for (int n = 0; n < count; n++) {
      final word = candidates[_random.nextInt(candidates.length)];
      for (int attempt = 0; attempt < 28; attempt++) {
        final startR = _random.nextInt(rows);
        final startC = _random.nextInt(cols);
        final dir = directions[_random.nextInt(directions.length)];
        if (_tryPlaceWord(word, startR, startC, dir.x, dir.y)) break;
      }
    }
  }

  bool _tryPlaceWord(String word, int startR, int startC, int dr, int dc) {
    final cells = <Point<int>>[];
    var r = startR;
    var c = startC;
    for (int i = 0; i < word.length; i++) {
      if (r < 0 || r >= rows || c < 0 || c >= cols) return false;
      if (grid[r][c].isBlocker) return false;
      cells.add(Point(r, c));
      r += dr;
      c += dc;
    }
    for (int i = 0; i < word.length; i++) {
      final p = cells[i];
      grid[p.x][p.y] = CrashTile(kind: CrashTileKind.letter, value: word[i]);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.watch<SkinManager>().currentSkin;
    final state = context.watch<GameStateManager>();
    final char = CharacterManager().getById(state.selectedCharacterId);
    final builtWord = _buildSelectedPreviewWord();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(skin.backgroundPath, fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.1))),
          AppSafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  GameTopBar(title: 'WORD CRASH', stage: _stage, state: state, showStageChip: false),
                  if (_isTutorialStage) const SizedBox(height: 8),
                  _stageGoalCard(),
                  const SizedBox(height: 8),
                  Container(
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
                            '${char.name}: ${char.hints['word_crash'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (_isTutorialStage) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('?쒗넗由ъ뼹 ?ㅽ뀒?댁??먯꽌???뚰듃瑜??ъ슜?????놁뒿?덈떎.')),
                              );
                              return;
                            }
                            final result = await state.consumeHint(
                              gameId: 'word_crash',
                              baseCost: 3,
                              cooldown: const Duration(seconds: 20),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result.ok ? 'Hint used.' : result.message)),
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
                      Expanded(child: _metric('Combo', '$_combo')),
                      const SizedBox(width: 8),
                      Expanded(child: _metric('Target', '$_wordsClearedInStage / ${_goal.targetWords}')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
            child: Text(
                      '* ?ㅽ? 蹂대꼫?? ! ??깂, X 釉붾줈而?| ?⑥? ?ㅼ닔: ${_goal.missLimitBeforeHeart - _mistakesInStage}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: cols / rows,
                      child: AnimatedContainer(
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
                            final isPopping = _poppingCells.contains(point);
                            return GestureDetector(
                              onTap: () => _pick(point),
                              child: AnimatedScale(
                                scale: isPopping ? 0.05 : (isPicked ? 1.06 : 1),
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeInBack,
                                child: AnimatedOpacity(
                                  opacity: isPopping ? 0 : 1,
                                  duration: const Duration(milliseconds: 190),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    decoration: _tileDecoration(tile, isPicked),
                                    child: Center(
                                      child: Text(
                                        tile.value,
                                        style: TextStyle(
                                          fontSize: tile.isLetter ? 21 : 19,
                                          fontWeight: FontWeight.w900,
                                          color: tile.isLetter
                                              ? (isPicked ? Colors.white : const Color(0xFF0B132B))
                                              : (tile.isBooster ? const Color(0xFF4A3200) : Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() {
                            selected.clear();
                            if (_isTutorialStage) _tutorialStep = 0;
                          }),
                          child: const Text('Clear Select'),
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

  Widget _stageGoalCard() {
    final obstacle = _goal.blockerRate > 0 ? ' | Obstacle Stage' : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C7ED6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'STAGE $_stage | Clear words ${_goal.targetWords}$obstacle',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _tutorialCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
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
                ? '1단계: 고정 보드에서 GAME 경로를 선택하세요.'
                : _tutorialStep == 1
                    ? '2단계: 인접한 4칸으로 GAME을 완성하세요.'
                    : _tutorialStep == 2
                        ? '3단계: Pop Word를 눌러 제출하세요.'
                        : '완료: Stage 1은 GAME 고정 튜토리얼입니다.',
            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFD9480F)),
          ),
          const SizedBox(height: 4),
          const Text('1) Stage 1 보드는 고정 세팅입니다.'),
          const Text('2) 정답 단어 GAME으로 제출이 유도됩니다.'),
          const Text('3) 튜토리얼 목표는 단어 1개 클리어입니다.'),
          const Text('4) 튜토리얼에서는 힌트가 비활성화됩니다.'),
        ],
      ),
    );
  }

  BoxDecoration _tileDecoration(CrashTile tile, bool isPicked) {
    if (tile.isBlocker) {
      return BoxDecoration(
        color: const Color(0xFF343A40),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.black54),
      );
    }
    if (tile.isBomb) {
      return BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1.5),
      );
    }
    if (tile.isBooster) {
      return BoxDecoration(
        color: const Color(0xFFFFD43B),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFCC9A06), width: 1.5),
      );
    }
    if (isPicked) {
      return BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF59F00), Color(0xFFF76707)]),
        borderRadius: BorderRadius.circular(9),
      );
    }
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF8F9FA), Color(0xFFE9ECEF)],
      ),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xFFCED4DA)),
      boxShadow: const [
        BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 2)),
      ],
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

  void _pick(Point<int> point) {
    if (_poppingCells.isNotEmpty) return;
    if (grid[point.x][point.y].isBlocker) {
      _showToast('Blocker tile cannot be selected.');
      return;
    }
    setState(() {
      if (selected.isEmpty) {
        selected.add(point);
        if (_isTutorialStage) {
          _updateTutorialStepFromSelection();
        }
        return;
      }
      if (selected.contains(point)) {
        selected.remove(point);
        if (_isTutorialStage) {
          _updateTutorialStepFromSelection();
        }
        return;
      }
      final last = selected.last;
      final adjacent = (last.x - point.x).abs() <= 1 && (last.y - point.y).abs() <= 1;
      if (adjacent) {
        selected.add(point);
        if (_isTutorialStage) {
          _updateTutorialStepFromSelection();
        }
      }
    });
  }

  String _buildSelectedPreviewWord() {
    return selected.map((p) {
      final tile = grid[p.x][p.y];
      if (tile.isLetter) return tile.value;
      return _specialWildcard;
    }).join();
  }

  Future<void> _submit(GameStateManager state) async {
    if (_isTutorialStage && _tutorialStep < 2) {
      _showToast('?쒗넗由ъ뼹: 癒쇱? 議곌굔??留욊쾶 釉붾줉???좏깮?섏꽭??');
      return;
    }
    final selectedTiles = selected.map((p) => grid[p.x][p.y]).toList();
    if (_isTutorialStage && selectedTiles.length < _tutorialTargetWord.length) {
      _showToast('튜토리얼: GAME 4글자를 완성해 제출하세요.');
      return;
    }
    if (selectedTiles.length < 3) {
      _showToast('Select at least 3 blocks.');
      return;
    }
    if (selectedTiles.every((t) => !t.isLetter)) {
      _showToast('Include at least one letter block.');
      return;
    }

    final letterCount = selectedTiles.where((t) => t.isLetter).length;
    final wildcardCount = selectedTiles.length - letterCount;
    if (letterCount < 2) {
      _showToast('Select at least 2 letter blocks.');
      return;
    }
    if (wildcardCount > 1) {
      _showToast('Only one special block can be used.');
      return;
    }

    final pattern = selectedTiles.map((t) => t.isLetter ? t.value : _specialWildcard).join();
    final matchedWord = _repo.findCrashWordByPattern(
      pattern,
      wildcard: _specialWildcard,
      requireUnique: true,
    );
    if (_isTutorialStage && matchedWord != _tutorialTargetWord) {
      _showToast('?쒗넗由ъ뼹: Stage 1? GAME ?좏깮?쇰줈 吏꾪뻾?⑸땲??');
      return;
    }
    final hasBomb = selectedTiles.any((t) => t.isBomb);
    final hasBooster = selectedTiles.any((t) => t.isBooster);

    if (matchedWord == null) {
      _combo = 0;
      _mistakesInStage += 1;
      selected.clear();
      if (_isTutorialStage) {
        _tutorialStep = 0;
      }
      var consumedHeart = false;
      if (_mistakesInStage >= _goal.missLimitBeforeHeart) {
        await state.consumeHeart();
        _mistakesInStage = 0;
        consumedHeart = true;
      }
      if (!mounted) return;
      setState(() {});
      _showToast(
        consumedHeart
            ? 'Miss: $pattern (too many misses, -1 heart)'
            : 'Miss: $pattern',
      );
      return;
    }

    _combo += 1;
    _wordsClearedInStage += 1;
    _mistakesInStage = 0;
    final longWordBonus = matchedWord.length >= 6 ? 1 : 0;
    final gainedStars = (hasBooster ? 1 : 0) + longWordBonus;
    if (gainedStars > 0) {
      await state.addStars(gainedStars);
    }

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

    if (!mounted) return;
    setState(() {
      _poppingCells
        ..clear()
        ..addAll(removalSet);
    });
    await Future<void>.delayed(const Duration(milliseconds: 220));

    for (final point in removalSet) {
      grid[point.x][point.y] = CrashTile(kind: CrashTileKind.letter, value: '');
    }
    _collapseGrid();
    selected.clear();
    if (_isTutorialStage) {
      _tutorialStep = 0;
    }

    final cleared = _wordsClearedInStage >= _goal.targetWords;
    if (cleared) {
      const stageBonus = 1;
      await state.addStars(stageBonus);
      final nextStage = _stage + 1;
      await state.setBestStageIfHigher('word_crash', nextStage);
      if (!mounted) return;
      setState(() {
        _poppingCells.clear();
      });
      await _showStageClearDialog(
        matchedWord: matchedWord,
        starsDelta: gainedStars + stageBonus,
        nextStage: nextStage,
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _poppingCells.clear();
    });
    _showToast(
      gainedStars > 0
          ? 'Word popped: $matchedWord (+$gainedStars stars)'
          : 'Word popped: $matchedWord',
    );
  }

  void _collapseGrid() {
    for (int c = 0; c < cols; c++) {
      final blockerRows = <int>{};
      for (int r = 0; r < rows; r++) {
        if (grid[r][c].isBlocker) {
          blockerRows.add(r);
        }
      }

      final colValues = <CrashTile>[];
      for (int r = rows - 1; r >= 0; r--) {
        final tile = grid[r][c];
        if (tile.isBlocker) continue;
        if (tile.value.isNotEmpty) {
          colValues.add(tile);
        }
      }

      final freeCount = rows - blockerRows.length;
      while (colValues.length < freeCount) {
        colValues.add(_randomTile(allowBlocker: false));
      }

      for (int r = rows - 1, i = 0; r >= 0; r--) {
        if (blockerRows.contains(r)) continue;
        grid[r][c] = colValues[i];
        i++;
      }
    }
    _injectPlayableWords(count: max(1, _goal.injectCount - 1), maxLength: _goal.maxWordLength);
  }

  Future<void> _showStageClearDialog({
    required String matchedWord,
    required int starsDelta,
    required int nextStage,
  }) async {
    if (!mounted || _dialogOpen) return;
    _dialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ReadableResultDialog(
          title: 'Stage Clear',
          success: true,
          headline: 'Final word: $matchedWord',
          lines: [
            ResultLine(label: 'Stage Progress', value: '$_wordsClearedInStage / ${_goal.targetWords}'),
            ResultLine(label: 'Reward', value: '+$starsDelta stars', accent: true),
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
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _setupStage(nextStage);
                });
              },
              child: const Text('Next Stage'),
            ),
          ],
        );
      },
    );
    _dialogOpen = false;
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _updateTutorialStepFromSelection() {
    if (!_isTutorialStage) return;
    if (selected.isEmpty) {
      _tutorialStep = 0;
      return;
    }
    final selectedTiles = selected.map((p) => grid[p.x][p.y]).toList();
    final letterCount = selectedTiles.where((t) => t.isLetter).length;
    if (selected.length >= _tutorialTargetWord.length && letterCount >= _tutorialTargetWord.length) {
      _tutorialStep = 2;
    } else {
      _tutorialStep = 1;
    }
  }
}

