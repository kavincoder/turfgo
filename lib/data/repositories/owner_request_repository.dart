import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../models/owner_request.dart';

class OwnerRequestRepository {
  final _db = FirebaseFirestore.instance; // read-only streams
  final _storage = FirebaseStorage.instance;
  final _functions = FirebaseFunctions.instance;

  /// Submit a new owner registration request via Cloud Function.
  /// Enforces rate limit (2/day) and blocks duplicate pending requests.
  Future<String> submitRequest(OwnerRequest request) async {
    // toMap() contains FieldValue.serverTimestamp() (and server-owned status
    // fields), which can't be sent to a callable. The CF sets those itself.
    final payload = request.toMap()
      ..remove('createdAt')
      ..remove('status')
      ..remove('rejectionReason');
    final result = await _functions
        .httpsCallable('submitOwnerRequest')
        .call(payload);
    return result.data['requestId'] as String;
  }

  /// Upload a turf photo to Firebase Storage. Returns the download URL.
  Future<String> uploadTurfPhoto({
    required String userId,
    required File file,
    required int index,
  }) async {
    final ref = _storage
        .ref()
        .child('owner_requests')
        .child(userId)
        .child('photo_${index}_${DateTime.now().millisecondsSinceEpoch}.jpg');

    final uploadTask = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return uploadTask.ref.getDownloadURL();
  }

  /// Stream the current user's owner request (if any).
  Stream<OwnerRequest?> getUserRequestStream(String userId) {
    return _db
        .collection('ownerRequests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((s) {
      if (s.docs.isEmpty) return null;
      return OwnerRequest.fromFirestore(s.docs.first);
    });
  }

  /// Stream all pending requests (admin).
  Stream<List<OwnerRequest>> getAllRequestsStream() {
    return _db
        .collection('ownerRequests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(OwnerRequest.fromFirestore).toList());
  }

  /// Admin approves a request via Cloud Function.
  Future<void> approveRequest(String requestId) async {
    await _functions
        .httpsCallable('approveOwnerRequest')
        .call({'requestId': requestId});
  }

  /// Admin rejects a request via Cloud Function.
  Future<void> rejectRequest(String requestId, String reason) async {
    await _functions
        .httpsCallable('rejectOwnerRequest')
        .call({'requestId': requestId, 'reason': reason});
  }
}
