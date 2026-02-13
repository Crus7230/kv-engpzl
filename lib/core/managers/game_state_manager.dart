import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_sync_manager.dart';

class HintUsageResult {
  const HintUsageResult({
    required this.ok,
    this.cost = 0,
    this.cooldownLeft = Duration.zero,
    this.message = '',
  });

  final bool ok;
  final int cost;
  final Duration cooldownLeft;
  final String message;
}

class GameStateManager extends ChangeNotifier {
  late SharedPreferences _prefs;

  int hearts = 5;
  int stars = 0;
  String selectedCharacterId = 'CHAR_A';
  final Set<String> unlockedCharacters = {'CHAR_A'};
  final Map<String, int> bestStages = {
    'wordle': 1,
    'word_clue': 1,
    'anagram': 1,
    'word_crash': 1,
  };
  final Map<String, int> playCounts = {
    'wordle': 0,
    'word_clue': 0,
    'anagram': 0,
    'word_crash': 0,
  };

  final Map<String, DateTime> _lastHintUsedAt = {};
  final Map<String, int> _hintUseCount = {};
  Future<void> Function(Map<String, dynamic> payload)? _remoteSyncHandler;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    hearts = _prefs.getInt('user_hearts') ?? 5;
    stars = _prefs.getInt('user_stars') ?? 0;
    selectedCharacterId = _prefs.getString('selected_character') ?? 'CHAR_A';
    final unlocked = _prefs.getStringList('unlocked_characters');
    if (unlocked != null && unlocked.isNotEmpty) {
      unlockedCharacters
        ..clear()
        ..addAll(unlocked);
    }
    final stagePairs = _prefs.getStringList('best_stages') ?? const [];
    for (final pair in stagePairs) {
      final parts = pair.split(':');
      if (parts.length != 2) continue;
      bestStages[parts[0]] = int.tryParse(parts[1]) ?? 1;
    }
    final playPairs = _prefs.getStringList('play_counts') ?? const [];
    for (final pair in playPairs) {
      final parts = pair.split(':');
      if (parts.length != 2) continue;
      playCounts[parts[0]] = int.tryParse(parts[1]) ?? 0;
    }
  }

  void setRemoteSyncHandler(Future<void> Function(Map<String, dynamic>) handler) {
    _remoteSyncHandler = handler;
  }

  Map<String, dynamic> exportState() {
    return {
      'hearts': hearts,
      'stars': stars,
      'selectedCharacterId': selectedCharacterId,
      'unlockedCharacters': unlockedCharacters.toList(),
      'bestStages': bestStages,
      'playCounts': playCounts,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> applyRemoteState(Map<String, dynamic> payload) async {
    hearts = (payload['hearts'] as num?)?.toInt() ?? hearts;
    stars = (payload['stars'] as num?)?.toInt() ?? stars;
    selectedCharacterId = payload['selectedCharacterId'] as String? ?? selectedCharacterId;

    final remoteChars = payload['unlockedCharacters'];
    if (remoteChars is List) {
      unlockedCharacters
        ..clear()
        ..addAll(remoteChars.whereType<String>());
      if (unlockedCharacters.isEmpty) {
        unlockedCharacters.add('CHAR_A');
      }
    }

    final remoteStages = payload['bestStages'];
    if (remoteStages is Map) {
      for (final entry in remoteStages.entries) {
        final key = entry.key.toString();
        final val = (entry.value as num?)?.toInt() ?? 1;
        bestStages[key] = val;
      }
    }
    final remoteCounts = payload['playCounts'];
    if (remoteCounts is Map) {
      for (final entry in remoteCounts.entries) {
        final key = entry.key.toString();
        final val = (entry.value as num?)?.toInt() ?? 0;
        playCounts[key] = val;
      }
    }

    await _save(triggerRemote: false);
    notifyListeners();
  }

  Future<void> _save({bool triggerRemote = true}) async {
    await _prefs.setInt('user_hearts', hearts);
    await _prefs.setInt('user_stars', stars);
    await _prefs.setString('selected_character', selectedCharacterId);
    await _prefs.setStringList('unlocked_characters', unlockedCharacters.toList());
    await _prefs.setStringList(
      'best_stages',
      bestStages.entries.map((e) => '${e.key}:${e.value}').toList(),
    );
    await _prefs.setStringList(
      'play_counts',
      playCounts.entries.map((e) => '${e.key}:${e.value}').toList(),
    );
    if (triggerRemote && _remoteSyncHandler != null) {
      unawaited(_remoteSyncHandler!(exportState()));
    }
  }

  Future<void> persistLocalOnly() async {
    await _save(triggerRemote: false);
  }

  void notifyUi() {
    notifyListeners();
  }

  Future<void> addStars(int amount) async {
    stars += amount;
    await _save();
    notifyListeners();
  }

  Future<void> consumeHeart() async {
    if (hearts > 0) {
      hearts -= 1;
      await _save();
      notifyListeners();
    }
  }

  Future<void> recoverHeart() async {
    if (hearts < 5) {
      hearts += 1;
      await _save();
      notifyListeners();
    }
  }

  Future<bool> spendStars(int amount) async {
    if (stars < amount) return false;
    stars -= amount;
    await _save();
    notifyListeners();
    return true;
  }

  Future<bool> unlockCharacter(String characterId, int price) async {
    if (unlockedCharacters.contains(characterId)) return true;
    final paid = await spendStars(price);
    if (!paid) return false;
    unlockedCharacters.add(characterId);
    await _save();
    notifyListeners();
    return true;
  }

  Future<void> equipCharacter(String characterId) async {
    if (!unlockedCharacters.contains(characterId)) return;
    selectedCharacterId = characterId;
    await _save();
    notifyListeners();
  }

  int getBestStage(String gameId) {
    return bestStages[gameId] ?? 1;
  }

  int getPlayCount(String gameId) {
    return playCounts[gameId] ?? 0;
  }

  Future<void> increasePlayCount(String gameId) async {
    playCounts[gameId] = (playCounts[gameId] ?? 0) + 1;
    await _save();
    notifyListeners();
  }

  Future<void> setBestStageIfHigher(String gameId, int stage) async {
    final current = bestStages[gameId] ?? 1;
    if (stage <= current) return;
    bestStages[gameId] = stage;
    await _save();
    await CloudSyncManager.instance.pushLeaderboardStage(
      gameId: gameId,
      stage: stage,
    );
    notifyListeners();
  }

  Future<HintUsageResult> consumeHint({
    required String gameId,
    required int baseCost,
    required Duration cooldown,
  }) async {
    final now = DateTime.now();
    final lastUsed = _lastHintUsedAt[gameId];
    if (lastUsed != null) {
      final elapsed = now.difference(lastUsed);
      if (elapsed < cooldown) {
        final left = cooldown - elapsed;
        return HintUsageResult(
          ok: false,
          cooldownLeft: left,
          message: 'Hint cooldown: ${left.inSeconds}s left.',
        );
      }
    }

    final usedCount = _hintUseCount[gameId] ?? 0;
    final dynamicCost = baseCost + usedCount;
    if (stars < dynamicCost) {
      return HintUsageResult(
        ok: false,
        cost: dynamicCost,
        message: 'Need $dynamicCost stars for this hint.',
      );
    }

    stars -= dynamicCost;
    _lastHintUsedAt[gameId] = now;
    _hintUseCount[gameId] = usedCount + 1;
    await _save();
    notifyListeners();
    return HintUsageResult(ok: true, cost: dynamicCost, message: 'Hint used (-$dynamicCost stars).');
  }
}
