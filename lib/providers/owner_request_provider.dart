import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/owner_request_repository.dart';
import '../models/owner_request.dart';

final ownerRequestRepositoryProvider = Provider<OwnerRequestRepository>(
  (ref) => OwnerRequestRepository(),
);

/// Stream the current user's latest owner request.
final userOwnerRequestProvider = StreamProvider<OwnerRequest?>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(ownerRequestRepositoryProvider).getUserRequestStream(uid);
});

/// Stream all owner requests (admin only).
final allOwnerRequestsProvider = StreamProvider<List<OwnerRequest>>((ref) {
  return ref.watch(ownerRequestRepositoryProvider).getAllRequestsStream();
});
