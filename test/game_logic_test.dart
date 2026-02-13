import 'package:flutter_test/flutter_test.dart';
import 'package:kavon_eng_puzzle/core/managers/game_state_manager.dart';
import 'package:kavon_eng_puzzle/core/managers/word_repository.dart';
import 'package:kavon_eng_puzzle/features/game_wordle/wordle_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Word repository stage-based generation works', () async {
    final repo = WordRepository.instance;
    await repo.preload();
    final s1 = await repo.getWordleWordForStage(1);
    final s6 = await repo.getWordleWordForStage(6);
    final anagram = repo.getAnagramRound();
    final clue = repo.getWordClueRound();

    expect(s1.word.length, anyOf(4, 5));
    expect(s6.word.length, anyOf(4, 5));
    expect(anagram.seed.isNotEmpty, true);
    expect(anagram.coreWords.isNotEmpty, true);
    expect(clue.word.isNotEmpty, true);
  });

  test('Word repository pool is large when assets are available', () async {
    final repo = WordRepository.instance;
    await repo.preload();
    final stats = repo.getPoolStats();
    if (repo.loadedFromAssets) {
      expect(stats['wordle4_allowed']!, greaterThan(1000));
      expect(stats['wordle5_allowed']!, greaterThan(2000));
      expect(stats['clue_words']!, greaterThan(3000));
      expect(stats['anagram_rounds']!, greaterThan(1000));
    } else {
      expect(stats['wordle4_allowed']!, greaterThan(10));
      expect(stats['wordle5_allowed']!, greaterThan(10));
      expect(stats['clue_words']!, greaterThan(5));
      expect(stats['anagram_rounds']!, greaterThan(1));
    }
  });

  test('Hint policy uses cooldown and dynamic cost', () async {
    SharedPreferences.setMockInitialValues({});
    final state = GameStateManager();
    await state.init();
    state.stars = 30;

    final first = await state.consumeHint(
      gameId: 'wordle',
      baseCost: 2,
      cooldown: const Duration(seconds: 10),
    );
    final second = await state.consumeHint(
      gameId: 'wordle',
      baseCost: 2,
      cooldown: const Duration(seconds: 10),
    );

    expect(first.ok, true);
    expect(first.cost, 2);
    expect(second.ok, false);
    expect(second.cooldownLeft.inSeconds > 0, true);
  });

  test('Wordle provider creates playable board', () async {
    SharedPreferences.setMockInitialValues({});
    final state = GameStateManager();
    await state.init();
    final provider = WordleProvider(state);
    await provider.initStage();

    expect(provider.board.length, 6);
    expect(provider.board.first.length, greaterThanOrEqualTo(4));
    expect(provider.currentWord.word.isNotEmpty, true);
  });

  test('Wordle rejects non-word guesses', () async {
    SharedPreferences.setMockInitialValues({});
    final state = GameStateManager();
    await state.init();
    final provider = WordleProvider(state);
    await provider.initStage();

    final invalid = provider.wordLength == 4 ? 'QZXW' : 'QZXWY';
    for (int i = 0; i < provider.wordLength; i++) {
      provider.board[provider.currentRow][i] = invalid[i];
    }
    provider.currentCol = provider.wordLength;

    final result = await provider.submit();
    expect(result, isNotNull);
    expect(result!.contains('not a valid English word'), true);
  });
}
