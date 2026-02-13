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
      if (user != null && user.isAnonymous) {
        try {
          final linked = await user.linkWithCredential(credential);
          user = linked.user;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            final signed = await _auth.signInWithCredential(credential);
            user = signed.user;
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
}
