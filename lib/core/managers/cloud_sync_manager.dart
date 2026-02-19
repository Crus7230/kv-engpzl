import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import 'game_state_manager.dart';
import 'user_profile_service.dart';

class SubmitWordSuggestionResult {
  const SubmitWordSuggestionResult({
    required this.ok,
    required this.message,
  });

  final bool ok;
  final String message;
}

class CloudSyncManager {
  CloudSyncManager._internal();
  static final CloudSyncManager instance = CloudSyncManager._internal();

  bool _enabled = false;
  bool get enabled => _enabled;

  String? _uid;
  Timer? _debounce;

  // Shared user doc with KP_Puzzles app, while KE game economy/progress stays in keGames.
  static const String _appNamespace = 'keGames';
  static const String _leaderboardPrefix = 'ke_';
  static const String _appId = 'ke';
  static final RegExp _wordPattern = RegExp(r'^[A-Z]{2,20}$');

  Future<void> init(GameStateManager gameState) async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
      _uid = auth.currentUser?.uid;
      if (_uid == null) return;
      _enabled = true;

      await UserProfileService.instance.ensureCurrentUserProfile();

      final userRef = FirebaseFirestore.instance.collection('users').doc(_uid);
      final doc = await userRef.get();
      final data = doc.data() ?? <String, dynamic>{};

      final keGames = (data[_appNamespace] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final appStarsBalance = (keGames['stars'] as num?)?.toInt();
      final appTotalStars = (keGames['totalStars'] as num?)?.toInt();
      final appHearts = (keGames['hearts'] as num?)?.toInt();
      final heartRefillStartedAtMs = (keGames['heartRefillStartedAtMs'] as num?)?.toInt();
      final attendanceStreak = (keGames['attendanceStreak'] as num?)?.toInt();
      final lastAttendanceDate = keGames['lastAttendanceDate'] as String?;
      final syncedStars = appStarsBalance ?? appTotalStars;
      if (syncedStars != null) {
        gameState.stars = syncedStars;
      }
      if (appTotalStars != null) {
        gameState.totalStarsEarned = appTotalStars;
      } else if (syncedStars != null) {
        gameState.totalStarsEarned = syncedStars;
      }
      if (gameState.totalStarsEarned < gameState.stars) {
        gameState.totalStarsEarned = gameState.stars;
      }
      if (appHearts != null) {
        gameState.hearts = appHearts.clamp(0, GameStateManager.maxHearts);
      }

      // App-specific records (separated)
      final bestStagesRaw = (keGames['bestStages'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      for (final entry in bestStagesRaw.entries) {
        gameState.bestStages[entry.key] = (entry.value as num?)?.toInt() ?? 1;
      }
      final playCountsRaw = (keGames['playCounts'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      for (final entry in playCountsRaw.entries) {
        gameState.playCounts[entry.key] = (entry.value as num?)?.toInt() ?? 0;
      }

      final unlockedRaw = (keGames['unlockedCharacters'] as List?)?.whereType<String>().toList() ?? const <String>[];
      if (unlockedRaw.isNotEmpty) {
        gameState.unlockedCharacters
          ..clear()
          ..addAll(unlockedRaw);
      }
      final selected = keGames['selectedCharacterId'] as String?;
      if (selected != null && gameState.unlockedCharacters.contains(selected)) {
        gameState.selectedCharacterId = selected;
      }
      if (heartRefillStartedAtMs != null) {
        await gameState.applyRemoteState({'heartRefillStartedAtMs': heartRefillStartedAtMs});
      }
      await gameState.applyRemoteState({
        'attendanceStreak': attendanceStreak,
        'lastAttendanceDate': lastAttendanceDate,
      });
      await gameState.persistLocalOnly();
      gameState.notifyUi();

      gameState.setRemoteSyncHandler(pushUserState);
      await pushUserState(gameState.exportState());
    } catch (e) {
      _enabled = false;
      if (kDebugMode) {
        debugPrint('Cloud sync init failed: $e');
      }
    }
  }

  Future<void> pushUserState(Map<String, dynamic> payload) async {
    if (!_enabled || _uid == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final bestStages = (payload['bestStages'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        final playCounts = (payload['playCounts'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        final unlockedChars = (payload['unlockedCharacters'] as List?)?.whereType<String>().toList() ?? <String>[];
        final stars = (payload['stars'] as num?)?.toInt() ?? 0;
        final totalStars = ((payload['totalStarsEarned'] as num?)?.toInt()) ??
            ((payload['totalStars'] as num?)?.toInt()) ??
            stars;
        final hearts = (payload['hearts'] as num?)?.toInt() ?? GameStateManager.maxHearts;
        final heartRefillStartedAtMs = (payload['heartRefillStartedAtMs'] as num?)?.toInt();
        final selectedCharacterId = payload['selectedCharacterId'] as String? ?? 'CHAR_A';
        final attendanceStreak = (payload['attendanceStreak'] as num?)?.toInt() ?? 0;
        final lastAttendanceDate = payload['lastAttendanceDate'] as String?;

        await FirebaseFirestore.instance.collection('users').doc(_uid).set({
          'lastActive': FieldValue.serverTimestamp(),
          // Separate KE app records.
          _appNamespace: {
            'appId': _appId,
            'stars': stars,
            'totalStars': totalStars,
            'hearts': hearts,
            'heartRefillStartedAtMs': heartRefillStartedAtMs,
            'bestStages': bestStages,
            'playCounts': playCounts,
            'selectedCharacterId': selectedCharacterId,
            'unlockedCharacters': unlockedChars,
            'attendanceStreak': attendanceStreak,
            'lastAttendanceDate': lastAttendanceDate,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        }, SetOptions(merge: true));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Cloud sync push failed: $e');
        }
      }
    });
  }

  Future<void> pushLeaderboardStage({
    required String gameId,
    required int stage,
  }) async {
    if (!_enabled || _uid == null) return;
    final scopedGameId = '$_leaderboardPrefix$gameId';
    final docId = '${scopedGameId}_$_uid';
    final ref = FirebaseFirestore.instance.collection('leaderboards').doc(docId);
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    final nickname = (userDoc.data()?['nickname'] as String?) ?? 'KE Player';
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {
          'appId': _appId,
          'gameId': scopedGameId,
          'userId': _uid,
          'nickname': nickname,
          'score': stage,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }
      final current = (snap.data()?['score'] as num?)?.toInt() ?? 1;
      if (stage > current) {
        tx.update(ref, {
          'appId': _appId,
          'score': stage,
          'nickname': nickname,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> clearKeGameData() async {
    if (!_enabled || _uid == null) return;
    _debounce?.cancel();
    _debounce = null;
    final db = FirebaseFirestore.instance;
    final userRef = db.collection('users').doc(_uid);
    await userRef.set({
      _appNamespace: FieldValue.delete(),
    }, SetOptions(merge: true));

    final lbSnap = await db.collection('leaderboards').where('userId', isEqualTo: _uid).get();
    if (lbSnap.docs.isEmpty) return;
    var batch = db.batch();
    var opCount = 0;
    for (final doc in lbSnap.docs) {
      final data = doc.data();
      final gameId = data['gameId'] as String? ?? '';
      if (!gameId.startsWith(_leaderboardPrefix)) continue;
      batch.delete(doc.reference);
      opCount += 1;
      if (opCount >= 350) {
        await batch.commit();
        batch = db.batch();
        opCount = 0;
      }
    }
    if (opCount > 0) {
      await batch.commit();
    }
  }

  Future<SubmitWordSuggestionResult> submitWordSuggestion({
    required String word,
    required String description,
    String? gameId,
  }) async {
    if (!_enabled || _uid == null) {
      return const SubmitWordSuggestionResult(
        ok: false,
        message: '서버 연결이 필요합니다. 온라인 상태에서 다시 시도해 주세요.\nServer is not connected. Please try again when online.',
      );
    }
    final normalizedWord = word.trim().toUpperCase();
    if (!_wordPattern.hasMatch(normalizedWord)) {
      return const SubmitWordSuggestionResult(
        ok: false,
        message: '단어는 영어 1개만 입력해 주세요 (2~20자).\nUse one English word only (2-20 letters).',
      );
    }
    final memo = description.trim();
    if (memo.length < 5) {
      return const SubmitWordSuggestionResult(
        ok: false,
        message: '추가 이유를 5자 이상 작성해 주세요. 한글/영어 모두 가능합니다.\nPlease add a short reason (5+ chars). Korean and English are both allowed.',
      );
    }
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      final nickname = (userDoc.data()?['nickname'] as String?)?.trim();
      await FirebaseFirestore.instance.collection('word_suggestions').add({
        'appId': _appId,
        'word': normalizedWord,
        'description': memo,
        'gameId': (gameId ?? 'all').trim(),
        'status': 'pending',
        'requestedBy': _uid,
        'requestedByNick': (nickname == null || nickname.isEmpty) ? 'Guest' : nickname,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return const SubmitWordSuggestionResult(
        ok: true,
        message: '제안이 접수되었습니다. 사전 개선에 도움 주셔서 감사합니다.\nSuggestion sent. Thanks for helping improve the dictionary.',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('submitWordSuggestion failed: $e');
      }
      return const SubmitWordSuggestionResult(
        ok: false,
        message: '전송에 실패했습니다. 잠시 후 다시 시도해 주세요.\nFailed to send suggestion. Please try again.',
      );
    }
  }
}

