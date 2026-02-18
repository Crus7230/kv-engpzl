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

class AttendanceResult {
  const AttendanceResult({
    required this.claimed,
    required this.streak,
    required this.starsGained,
    required this.message,
  });

  final bool claimed;
  final int streak;
  final int starsGained;
  final String message;
}

class GameStateManager extends ChangeNotifier {
  static const int maxHearts = 5;
  static const Duration heartRefillInterval = Duration(minutes: 5);

  late SharedPreferences _prefs;

  int hearts = maxHearts;
  int stars = 0;
  int totalStarsEarned = 0;
  String selectedCharacterId = 'CHAR_A';
  final Set<String> unlockedCharacters = {'CHAR_A'};
  final Map<String, int> bestStages = {
    'wordle': 1,
    'word_clue': 1,
    'sentence_code': 1,
    'anagram': 1,
    'word_crash': 1,
  };
  final Map<String, int> playCounts = {
    'wordle': 0,
    'word_clue': 0,
    'sentence_code': 0,
    'anagram': 0,
    'word_crash': 0,
  };
  final Set<String> stage1IntroSeenGames = <String>{};
  int attendanceStreak = 0;
  String? lastAttendanceDate;

  final Map<String, DateTime> _lastHintUsedAt = {};
  final Map<String, int> _hintUseCount = {};
  Future<void> Function(Map<String, dynamic> payload)? _remoteSyncHandler;
  DateTime? _heartRefillStartedAt;
  Timer? _heartRefillTicker;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    hearts = (_prefs.getInt('user_hearts') ?? maxHearts).clamp(0, maxHearts);
    stars = _prefs.getInt('user_stars') ?? 0;
    totalStarsEarned = _prefs.getInt('user_total_stars_earned') ?? stars;
    final refillStartedAtMs = _prefs.getInt('heart_refill_started_at_ms');
    if (refillStartedAtMs != null) {
      _heartRefillStartedAt = DateTime.fromMillisecondsSinceEpoch(refillStartedAtMs);
    }
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
    final introSeen = _prefs.getStringList('stage1_intro_seen_games');
    if (introSeen != null && introSeen.isNotEmpty) {
      stage1IntroSeenGames
        ..clear()
        ..addAll(introSeen);
    }
    attendanceStreak = (_prefs.getInt('attendance_streak') ?? 0).clamp(0, 9999);
    lastAttendanceDate = _prefs.getString('attendance_last_date');
    final recovered = _applyHeartRecoveryCatchUp();
    if (recovered) {
      await _save(triggerRemote: false);
    }
    _ensureHeartRefillTicker();
  }

  void setRemoteSyncHandler(Future<void> Function(Map<String, dynamic>) handler) {
    _remoteSyncHandler = handler;
  }

  Map<String, dynamic> exportState() {
    return {
      'hearts': hearts,
      'stars': stars,
      'totalStarsEarned': totalStarsEarned,
      'totalStars': totalStarsEarned,
      'heartRefillStartedAtMs': _heartRefillStartedAt?.millisecondsSinceEpoch,
      'selectedCharacterId': selectedCharacterId,
      'unlockedCharacters': unlockedCharacters.toList(),
      'bestStages': bestStages,
      'playCounts': playCounts,
      'stage1IntroSeenGames': stage1IntroSeenGames.toList(growable: false),
      'attendanceStreak': attendanceStreak,
      'lastAttendanceDate': lastAttendanceDate,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  Future<void> applyRemoteState(Map<String, dynamic> payload) async {
    hearts = ((payload['hearts'] as num?)?.toInt() ?? hearts).clamp(0, maxHearts);
    stars = (payload['stars'] as num?)?.toInt() ?? stars;
    final remoteTotal = ((payload['totalStarsEarned'] as num?)?.toInt()) ??
        ((payload['totalStars'] as num?)?.toInt());
    totalStarsEarned = remoteTotal ?? totalStarsEarned;
    if (totalStarsEarned < stars) {
      totalStarsEarned = stars;
    }
    final refillStartedAtMs = (payload['heartRefillStartedAtMs'] as num?)?.toInt();
    _heartRefillStartedAt = refillStartedAtMs == null
        ? _heartRefillStartedAt
        : DateTime.fromMillisecondsSinceEpoch(refillStartedAtMs);
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
    final remoteIntroSeen = payload['stage1IntroSeenGames'];
    if (remoteIntroSeen is List) {
      stage1IntroSeenGames
        ..clear()
        ..addAll(remoteIntroSeen.whereType<String>());
    }
    attendanceStreak = ((payload['attendanceStreak'] as num?)?.toInt() ?? attendanceStreak).clamp(0, 9999);
    final remoteAttendanceDate = payload['lastAttendanceDate'] as String?;
    if (remoteAttendanceDate != null && remoteAttendanceDate.trim().isNotEmpty) {
      lastAttendanceDate = remoteAttendanceDate;
    }

    _applyHeartRecoveryCatchUp();
    _ensureHeartRefillTicker();
    await _save(triggerRemote: false);
    notifyListeners();
  }

  Future<void> _save({bool triggerRemote = true}) async {
    await _prefs.setInt('user_hearts', hearts);
    await _prefs.setInt('user_stars', stars);
    await _prefs.setInt('user_total_stars_earned', totalStarsEarned);
    if (_heartRefillStartedAt != null) {
      await _prefs.setInt('heart_refill_started_at_ms', _heartRefillStartedAt!.millisecondsSinceEpoch);
    } else {
      await _prefs.remove('heart_refill_started_at_ms');
    }
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
    await _prefs.setStringList('stage1_intro_seen_games', stage1IntroSeenGames.toList(growable: false));
    await _prefs.setInt('attendance_streak', attendanceStreak);
    if (lastAttendanceDate == null) {
      await _prefs.remove('attendance_last_date');
    } else {
      await _prefs.setString('attendance_last_date', lastAttendanceDate!);
    }
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
    if (amount <= 0) return;
    stars += amount;
    totalStarsEarned += amount;
    await _save();
    notifyListeners();
  }

  Future<void> consumeHeart() async {
    if (hearts > 0) {
      hearts -= 1;
      _heartRefillStartedAt ??= DateTime.now();
      _ensureHeartRefillTicker();
      await _save();
      notifyListeners();
    }
  }

  bool get hasPlayableHeart => hearts > 0;

  bool get canCheckInToday => lastAttendanceDate != _todayKey();

  Future<AttendanceResult> claimAttendance() async {
    final today = _todayKey();
    if (lastAttendanceDate == today) {
      return AttendanceResult(
        claimed: false,
        streak: attendanceStreak,
        starsGained: 0,
        message: 'Already checked in today.',
      );
    }

    if (lastAttendanceDate == _todayKey(daysOffset: -1)) {
      attendanceStreak += 1;
    } else {
      attendanceStreak = 1;
    }
    lastAttendanceDate = today;

    final dailyStars = 1;
    final streakBonus = attendanceStreak % 7 == 0 ? 5 : 0;
    final milestoneBonus = attendanceStreak % 100 == 0 ? attendanceStreak : 0;
    final starsGained = dailyStars + streakBonus + milestoneBonus;
    stars += starsGained;
    totalStarsEarned += starsGained;

    _applyHeartRecoveryCatchUp();
    _ensureHeartRefillTicker();
    await _save();
    notifyListeners();
    final parts = <String>['+$dailyStars daily'];
    if (streakBonus > 0) parts.add('+$streakBonus weekly');
    if (milestoneBonus > 0) parts.add('+$milestoneBonus milestone');
    return AttendanceResult(
      claimed: true,
      streak: attendanceStreak,
      starsGained: starsGained,
      message: 'Attendance complete (${parts.join(', ')}).',
    );
  }

  Future<void> recoverHeart() async {
    if (hearts < maxHearts) {
      hearts += 1;
      if (hearts >= maxHearts) {
        _heartRefillStartedAt = null;
      } else {
        _heartRefillStartedAt = DateTime.now();
      }
      _ensureHeartRefillTicker();
      await _save();
      notifyListeners();
    }
  }

  Future<void> resetProgressForPrelaunch() async {
    hearts = maxHearts;
    stars = 0;
    totalStarsEarned = 0;
    selectedCharacterId = 'CHAR_A';
    unlockedCharacters
      ..clear()
      ..add('CHAR_A');
    bestStages
      ..clear()
      ..addAll({
        'wordle': 1,
        'word_clue': 1,
        'sentence_code': 1,
        'anagram': 1,
        'word_crash': 1,
      });
    playCounts
      ..clear()
      ..addAll({
        'wordle': 0,
        'word_clue': 0,
        'sentence_code': 0,
        'anagram': 0,
        'word_crash': 0,
      });
    stage1IntroSeenGames.clear();
    attendanceStreak = 0;
    lastAttendanceDate = null;
    _heartRefillStartedAt = null;
    _lastHintUsedAt.clear();
    _hintUseCount.clear();
    _ensureHeartRefillTicker();
    await _save();
    notifyListeners();
  }

  Future<bool> spendStars(int amount) async {
    if (stars < amount) return false;
    stars -= amount;
    await _save();
    notifyListeners();
    return true;
  }

  int get spentStars => (totalStarsEarned - stars).clamp(0, 1 << 30);

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

  bool hasSeenStage1Intro(String gameId) {
    return stage1IntroSeenGames.contains(gameId);
  }

  Future<void> markStage1IntroSeen(String gameId) async {
    if (stage1IntroSeenGames.contains(gameId)) return;
    stage1IntroSeenGames.add(gameId);
    await _save();
    notifyListeners();
  }

  int getPlayCount(String gameId) {
    return playCounts[gameId] ?? 0;
  }

  Future<AttendanceResult?> increasePlayCount(String gameId) async {
    playCounts[gameId] = (playCounts[gameId] ?? 0) + 1;
    AttendanceResult? attendance;
    if (canCheckInToday) {
      attendance = await claimAttendance();
      return attendance;
    }
    await _save();
    notifyListeners();
    return attendance;
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

  Duration get timeUntilNextHeart {
    if (hearts >= maxHearts) return Duration.zero;
    final startedAt = _heartRefillStartedAt;
    if (startedAt == null) return heartRefillInterval;
    final remain = heartRefillInterval - DateTime.now().difference(startedAt);
    return remain.isNegative ? Duration.zero : remain;
  }

  String get nextHeartCountdownText {
    if (hearts >= maxHearts) return 'FULL';
    final remain = timeUntilNextHeart;
    final mm = remain.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = remain.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  bool _applyHeartRecoveryCatchUp() {
    var changed = false;
    final now = DateTime.now();
    if (hearts >= maxHearts) {
      if (_heartRefillStartedAt != null) {
        _heartRefillStartedAt = null;
        changed = true;
      }
      return changed;
    }

    _heartRefillStartedAt ??= now;
    final elapsed = now.difference(_heartRefillStartedAt!);
    final ticks = elapsed.inSeconds ~/ heartRefillInterval.inSeconds;
    if (ticks <= 0) return changed;

    final recovered = (hearts + ticks).clamp(0, maxHearts);
    if (recovered != hearts) {
      hearts = recovered;
      changed = true;
    }

    if (hearts >= maxHearts) {
      _heartRefillStartedAt = null;
      changed = true;
    } else {
      _heartRefillStartedAt = _heartRefillStartedAt!.add(Duration(seconds: ticks * heartRefillInterval.inSeconds));
      changed = true;
    }
    return changed;
  }

  void _ensureHeartRefillTicker() {
    _heartRefillTicker?.cancel();
    _heartRefillTicker = null;
    if (hearts >= maxHearts) return;

    _heartRefillTicker = Timer.periodic(const Duration(seconds: 1), (_) async {
      final changed = _applyHeartRecoveryCatchUp();
      if (changed) {
        await _save();
      }
      notifyListeners();
      if (hearts >= maxHearts) {
        _heartRefillTicker?.cancel();
        _heartRefillTicker = null;
      }
    });
  }

  @override
  void dispose() {
    _heartRefillTicker?.cancel();
    super.dispose();
  }

  String _todayKey({int daysOffset = 0}) {
    final day = DateTime.now().add(Duration(days: daysOffset));
    final mm = day.month.toString().padLeft(2, '0');
    final dd = day.day.toString().padLeft(2, '0');
    return '${day.year}-$mm-$dd';
  }
}
