import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class RankingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _appId = 'ke';
  static const int _maxRankItems = 50;
  static const int _fetchWindow = 200;

  Future<List<Map<String, dynamic>>> getTotalStarRanking() async {
    try {
      // Keep query index-light to avoid "failed-precondition" on missing composite indexes.
      final snapshot = await _db
          .collection('users')
          .where('keGames.appId', isEqualTo: _appId)
          .limit(_fetchWindow)
          .get();
      final rows = snapshot.docs.map((d) {
        final data = d.data();
        final keGames = (data['keGames'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
        return {
          ...data,
          'keTotalStars': (keGames['totalStars'] as num?)?.toInt() ?? 0,
        };
      }).toList();
      rows.sort(
        (a, b) => ((b['keTotalStars'] as num?)?.toInt() ?? 0).compareTo(
          (a['keTotalStars'] as num?)?.toInt() ?? 0,
        ),
      );
      return rows.take(_maxRankItems).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('getTotalStarRanking failed: $e');
      }
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> getGameRanking(String gameId) async {
    final scopedGameId = 'ke_$gameId';
    try {
      final snapshot = await _db
          .collection('leaderboards')
          .where('gameId', whereIn: [scopedGameId, gameId])
          .limit(_fetchWindow)
          .get();
      final rows = snapshot.docs.map((d) => d.data()).where((row) {
        final appId = row['appId'] as String?;
        // Allow legacy rows without appId while still preferring current-app rows.
        return appId == null || appId == _appId;
      }).toList();
      rows.sort(
        (a, b) => ((b['score'] as num?)?.toInt() ?? 0).compareTo(
          (a['score'] as num?)?.toInt() ?? 0,
        ),
      );
      return rows.take(_maxRankItems).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('getGameRanking($gameId) failed: $e');
      }
      return const <Map<String, dynamic>>[];
    }
  }
}
