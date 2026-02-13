import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'nickname_generator.dart';

class UserProfileService {
  UserProfileService._internal();
  static final UserProfileService instance = UserProfileService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> ensureCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final ref = _db.collection('users').doc(user.uid);
    final doc = await ref.get();
    final data = doc.data() ?? <String, dynamic>{};

    var nickname = (data['nickname'] as String?) ?? '';
    var handle = (data['handle'] as String?) ?? '';

    if (nickname.isEmpty) {
      nickname = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!
          : NicknameGenerator.generate();
    }
    if (handle.isEmpty) {
      handle = _generateRandomHandle();
    }

    if ((user.displayName ?? '').isEmpty) {
      await user.updateDisplayName(nickname);
    }

    await ref.set({
      'uid': user.uid,
      'nickname': nickname,
      'handle': handle,
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'isAnonymous': user.isAnonymous,
      'lastLogin': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateNickname(String newName) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await user.updateDisplayName(newName);
    await _db.collection('users').doc(user.uid).set({
      'nickname': newName,
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final rankingDocs = await _db.collection('leaderboards').where('userId', isEqualTo: user.uid).get();
    final batch = _db.batch();
    for (final doc in rankingDocs.docs) {
      batch.update(doc.reference, {'nickname': newName});
    }
    await batch.commit();
  }

  Future<Map<String, String>> getMyProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'nickname': 'Unknown', 'handle': 'none#0000'};
    }
    final doc = await _db.collection('users').doc(user.uid).get();
    final data = doc.data() ?? <String, dynamic>{};
    return {
      'nickname': (data['nickname'] as String?) ?? (user.displayName ?? 'Unknown'),
      'handle': (data['handle'] as String?) ?? 'none#0000',
    };
  }

  String _generateRandomHandle() {
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    final rnd = Random();
    final letters = List.generate(4, (_) => chars[rnd.nextInt(chars.length)]).join();
    final digits = rnd.nextInt(10000).toString().padLeft(4, '0');
    return '$letters#$digits';
  }
}
