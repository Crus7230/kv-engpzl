import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/managers/game_state_manager.dart';
import '../../core/managers/sound_manager.dart';
import '../../core/managers/word_repository.dart';

enum TileStatus { initial, absent, present, correct }

enum WaveDifficulty { easy, medium, hard }

class WordleProvider extends ChangeNotifier {
  WordleProvider(this._gameState) {
    stage = _gameState.getBestStage('wordle');
    initStage();
  }

  final GameStateManager _gameState;
  final WordRepository _wordRepository = WordRepository.instance;
  final Random _random = Random();

  int stage = 1;
  int maxRows = 6;
  int currentRow = 0;
  int currentCol = 0;
  bool isLoading = false;
  bool isWon = false;
  bool isLost = false;

  late WordData currentWord;
  late int wordLength;
  late WaveDifficulty waveDifficulty;
  List<List<String>> board = [];
  List<List<TileStatus>> statusBoard = [];
  final Map<String, TileStatus> keyboardStates = {};

  int get stars => _gameState.stars;
  int get hearts => _gameState.hearts;

  Color get badgeColor {
    switch (waveDifficulty) {
      case WaveDifficulty.easy:
        return const Color(0xFF1C7ED6);
      case WaveDifficulty.medium:
        return const Color(0xFFF08C00);
      case WaveDifficulty.hard:
        return const Color(0xFFE03131);
    }
  }

  String get badgeLabel {
    switch (waveDifficulty) {
      case WaveDifficulty.easy:
        return 'WAVE BLUE';
      case WaveDifficulty.medium:
        return 'WAVE YELLOW';
      case WaveDifficulty.hard:
        return 'WAVE RED';
    }
  }

  Future<void> initStage() async {
    isLoading = true;
    notifyListeners();

    final roll = _random.nextDouble();
    if (roll < 0.4) {
      waveDifficulty = WaveDifficulty.easy;
      wordLength = 4;
    } else if (roll < 0.8) {
      waveDifficulty = WaveDifficulty.medium;
      wordLength = 5;
    } else {
      waveDifficulty = WaveDifficulty.hard;
      wordLength = 5;
    }

    currentWord = await _wordRepository.getWordleWordForStage(
      stage,
      preferredLength: wordLength,
    );
    wordLength = currentWord.word.length;
    board = List.generate(maxRows, (_) => List.generate(wordLength, (_) => ''));
    statusBoard = List.generate(maxRows, (_) => List.generate(wordLength, (_) => TileStatus.initial));
    keyboardStates.clear();
    currentRow = 0;
    currentCol = 0;
    isWon = false;
    isLost = false;
    isLoading = false;
    notifyListeners();
  }

  void typeKey(String key) {
    if (isLoading || isWon || isLost) return;
    if (currentCol >= wordLength) return;
    board[currentRow][currentCol] = key;
    currentCol += 1;
    SoundManager.instance.playTap();
    notifyListeners();
  }

  void backspace() {
    if (isLoading || isWon || isLost) return;
    if (currentCol == 0) return;
    currentCol -= 1;
    board[currentRow][currentCol] = '';
    notifyListeners();
  }

  Future<String?> submit() async {
    if (isLoading || isWon || isLost) return null;
    if (currentCol < wordLength) {
      return 'Enter $wordLength letters first.';
    }

    final guess = board[currentRow].join().toUpperCase();
    if (!_wordRepository.isValidWordleGuess(guess)) {
      return '"$guess" is not a valid English word.';
    }

    final target = currentWord.word.toUpperCase();
    final targetChars = target.split('');
    final guessChars = guess.split('');
    final usedTarget = List<bool>.filled(wordLength, false);

    for (int i = 0; i < wordLength; i++) {
      if (guessChars[i] == targetChars[i]) {
        statusBoard[currentRow][i] = TileStatus.correct;
        usedTarget[i] = true;
      }
    }

    for (int i = 0; i < wordLength; i++) {
      if (statusBoard[currentRow][i] == TileStatus.correct) continue;
      final exact = _findUnusedIndex(targetChars, usedTarget, guessChars[i]);
      if (exact != -1) {
        usedTarget[exact] = true;
        statusBoard[currentRow][i] = TileStatus.present;
      } else {
        statusBoard[currentRow][i] = TileStatus.absent;
      }
    }

    for (int i = 0; i < wordLength; i++) {
      final ch = guessChars[i];
      final next = statusBoard[currentRow][i];
      final current = keyboardStates[ch];
      keyboardStates[ch] = _prefer(current, next);
    }

    if (guess == target) {
      isWon = true;
      await _gameState.addStars(5);
      SoundManager.instance.playWin();
      notifyListeners();
      return null;
    }

    if (currentRow == maxRows - 1) {
      isLost = true;
      await _gameState.consumeHeart();
      notifyListeners();
      return null;
    }

    currentRow += 1;
    currentCol = 0;
    notifyListeners();
    return null;
  }

  Future<void> nextStage() async {
    stage += 1;
    await _gameState.setBestStageIfHigher('wordle', stage);
    await initStage();
  }

  Future<void> retryStage() async {
    await initStage();
  }

  String applyHint() {
    final target = currentWord.word.toUpperCase();
    for (int i = 0; i < wordLength; i++) {
      if (board[currentRow][i].isEmpty) {
        board[currentRow][i] = target[i];
        if (currentCol <= i) currentCol = i + 1;
        notifyListeners();
        return 'Hint: position ${i + 1} is ${target[i]}.';
      }
    }
    notifyListeners();
    return 'Hint: the first letter is ${target[0]}.';
  }

  TileStatus _prefer(TileStatus? current, TileStatus next) {
    if (current == TileStatus.correct) return TileStatus.correct;
    if (current == TileStatus.present && next == TileStatus.absent) return TileStatus.present;
    return next;
  }

  int _findUnusedIndex(List<String> target, List<bool> used, String char) {
    for (int i = 0; i < target.length; i++) {
      if (!used[i] && target[i] == char) return i;
    }
    return -1;
  }
}
