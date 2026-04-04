import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/owner_request.dart';

class OwnerRequestRepository {
  final _db = FirebaseFirestore.instance;

  Stream<OwnerRequest?> getUserRequestStream(String uid) {
    return _db
        .collection('ownerRequests')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isEmpty
            ? null
            : OwnerRequest.fromFirestore(s.docs.first));
  }

  Stream<List<OwnerRequest>> getAllRequestsStream() {
    return _db
        .collection('ownerRequests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(OwnerRequest.fromFirestore).toList());
  }

  Future<String> uploadTurfPhoto({
    required String userId,
    required File file,
    required int index,
  }) async {
    final ref = FirebaseStorage.instance
        .ref('ownerRequests/$userId/photo_$index.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<void> submitRequest(OwnerRequest request) {
    return _db.collection('ownerRequests').add(request.toMap());
  }
}
