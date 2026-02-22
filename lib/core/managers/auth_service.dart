import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'cloud_sync_manager.dart';
import 'game_state_manager.dart';
import 'user_profile_service.dart';

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

  Future<User?> linkWithGoogle(GameStateManager gameState) async {
    try {
      final googleUser = await _google.signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      User? user = _auth.currentUser;
      final localUidBeforeLogin = user?.uid;
      if (user != null && user.isAnonymous) {
        try {
          final linked = await user.linkWithCredential(credential);
          user = linked.user;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            final signed = await _auth.signInWithCredential(credential);
            user = signed.user;
            final serverUid = user?.uid;
            if (localUidBeforeLogin != null && serverUid != null && localUidBeforeLogin != serverUid) {
              await _mergeFriendsByUid(
                localUid: localUidBeforeLogin,
                serverUid: serverUid,
              );
            }
          } else {
            return null;
          }
        }
      } else {
        final signed = await _auth.signInWithCredential(credential);
        user = signed.user;
      }

      await UserProfileService.instance.ensureCurrentUserProfile();
      await CloudSyncManager.instance.init(gameState);
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<void> signOutToAnonymous(GameStateManager gameState) async {
    await _google.signOut();
    await _auth.signOut();
    await _auth.signInAnonymously();
    await UserProfileService.instance.ensureCurrentUserProfile();
    await CloudSyncManager.instance.init(gameState);
  }

  Future<void> _mergeFriendsByUid({
    required String localUid,
    required String serverUid,
  }) async {
    if (localUid == serverUid) return;
    final localSnap = await _db.collection('users').doc(localUid).collection('friends').get();
    final serverRef = _db.collection('users').doc(serverUid).collection('friends');
    final serverSnap = await serverRef.get();
    final existingIds = <String>{
      for (final doc in serverSnap.docs) doc.id,
    };

    var batch = _db.batch();
    var opCount = 0;
    for (final doc in localSnap.docs) {
      final data = doc.data();
      final friendUid = (data['uid'] as String?) ?? doc.id;
      if (friendUid.isEmpty || friendUid == serverUid || existingIds.contains(friendUid)) {
        continue;
      }
      batch.set(
        serverRef.doc(friendUid),
        {
          'uid': friendUid,
          'nickname': data['nickname'] ?? 'Unknown',
          'handle': data['handle'] ?? 'none#0000',
          'photoUrl': data['photoUrl'] ?? '',
          'addedAt': data['addedAt'] ?? FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      existingIds.add(friendUid);
      opCount += 1;
      if (opCount >= 350) {
        await batch.commit();
        batch = _db.batch();
        opCount = 0;
      }
    }
    if (opCount > 0) {
      await batch.commit();
    }
  }
}
