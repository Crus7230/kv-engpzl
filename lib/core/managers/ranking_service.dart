import 'package:cloud_firestore/cloud_firestore.dart';

class RankingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _appId = 'ke';

  Future<List<Map<String, dynamic>>> getTotalStarRanking() async {
    final snapshot = await _db
        .collection('users')
        .where('keGames.appId', isEqualTo: _appId)
        .orderBy('keGames.totalStars', descending: true)
        .limit(50)
        .get();
    return snapshot.docs.map((d) {
      final data = d.data();
      final keGames = (data['keGames'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      return {
        ...data,
        'keTotalStars': (keGames['totalStars'] as num?)?.toInt() ?? 0,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getGameRanking(String gameId) async {
    final snapshot = await _db
        .collection('leaderboards')
        .where('appId', isEqualTo: _appId)
        .where('gameId', isEqualTo: 'ke_$gameId')
        .orderBy('score', descending: true)
        .limit(50)
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }
}
