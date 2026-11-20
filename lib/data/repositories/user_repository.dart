import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/app_user.dart';

class UserRepository {
  final _db = FirebaseFirestore.instance;

  Stream<AppUser?> userStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map<AppUser?>((doc) {
          if (!doc.exists) return null;
          return AppUser.fromFirestore(doc);
        })
        .handleError((Object e, StackTrace st) {
          debugPrint('[UserRepository] userStream error: $e\n$st');
        });
  }

  /// Fresh server read of the user's role. Throws on network failure.
  Future<String?> fetchRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return (doc.data()?['role'] as String?)?.trim();
  }

  Future<void> updateName(String uid, String name) {
    return _db.collection('users').doc(uid).set(
      {'name': name.trim()},
      SetOptions(merge: true),
    );
  }
}
