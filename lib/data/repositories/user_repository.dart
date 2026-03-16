import 'package:cloud_firestore/cloud_firestore.dart';
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
        .handleError((_) {});
  }

  Future<void> updateName(String uid, String name) {
    return _db.collection('users').doc(uid).set(
      {'name': name.trim()},
      SetOptions(merge: true),
    );
  }
}
