import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>?> searchUserByHandle(String handleInput) async {
    if (!handleInput.contains('#')) return null;
    final query = await _db.collection('users').where('handle', isEqualTo: handleInput).limit(1).get();
    if (query.docs.isEmpty) return null;
    return query.docs.first.data();
  }

  Future<String> addFriend(Map<String, dynamic> targetUserData) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return 'Login required.';
    final targetUid = targetUserData['uid'] as String?;
    if (targetUid == null) return 'Invalid target user.';
    if (myUid == targetUid) return 'You cannot add yourself.';

    final myFriendRef = _db.collection('users').doc(myUid).collection('friends').doc(targetUid);
    final exists = await myFriendRef.get();
    if (exists.exists) return 'Already added.';

    await myFriendRef.set({
      'uid': targetUid,
      'nickname': targetUserData['nickname'] ?? 'Unknown',
      'handle': targetUserData['handle'] ?? 'none#0000',
      'photoUrl': targetUserData['photoUrl'] ?? '',
      'addedAt': FieldValue.serverTimestamp(),
    });
    return 'Added';
  }

  Stream<List<Map<String, dynamic>>> getMyFriendsStream() {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final list = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final uid = doc.data()['uid'] as String;
        final userDoc = await _db.collection('users').doc(uid).get();
        final userData = userDoc.data() ?? <String, dynamic>{};
        list.add({
          'uid': uid,
          'nickname': userData['nickname'] ?? doc.data()['nickname'] ?? 'Unknown',
          'handle': userData['handle'] ?? doc.data()['handle'] ?? 'none#0000',
          'photoUrl': userData['photoUrl'] ?? '',
          'lastActive': userData['lastActive'],
        });
      }
      return list;
    });
  }

  Future<void> removeFriend(String uid) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;
    await _db.collection('users').doc(myUid).collection('friends').doc(uid).delete();
  }

  bool isUserOnline(Timestamp? lastActive) {
    if (lastActive == null) return false;
    return DateTime.now().difference(lastActive.toDate()).inMinutes < 5;
  }
}
