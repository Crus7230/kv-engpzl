import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import 'game_state_manager.dart';
import 'user_profile_service.dart';

class CloudSyncManager {
  CloudSyncManager._internal();
  static final CloudSyncManager instance = CloudSyncManager._internal();

  bool _enabled = false;
  bool get enabled => _enabled;

  String? _uid;
  Timer? _debounce;

  // Shared user doc with KP_Puzzles app, but game progress is separated under keGames.
  static const String _appNamespace = 'keGames';
  static const String _leaderboardPrefix = 'ke_';

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

      final serverTotalStars = (data['totalStars'] as num?)?.toInt();
      final keGames = (data[_appNamespace] as Map<String, dynamic>?) ?? <String, dynamic>{};

      // Shared profile/stars inherited from 26version
      if (serverTotalStars != null && serverTotalStars > gameState.stars) {
        gameState.stars = serverTotalStars;
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
        final selectedCharacterId = payload['selectedCharacterId'] as String? ?? 'CHAR_A';

        await FirebaseFirestore.instance.collection('users').doc(_uid).set({
          // Keep common profile economy compatible with 26version.
          'totalStars': stars,
          'lastActive': FieldValue.serverTimestamp(),
          // Separate KE app records.
          _appNamespace: {
            'bestStages': bestStages,
            'playCounts': playCounts,
            'selectedCharacterId': selectedCharacterId,
            'unlockedCharacters': unlockedChars,
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
          'score': stage,
          'nickname': nickname,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
