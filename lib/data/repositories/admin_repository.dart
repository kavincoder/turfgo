import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../models/turf.dart';

class AdminRepository {
  final _db = FirebaseFirestore.instance;

  /// Streams all turfs (active + inactive).
  Stream<List<Turf>> getAllTurfsStream() {
    return _db.collection('turfs').snapshots().map(
          (s) => s.docs.map(Turf.fromFirestore).toList(),
        );
  }

  /// Streams all bookings across all turfs.
  Stream<List<Booking>> getAllBookingsStream() {
    return _db.collection('bookings').snapshots().map((s) {
      final list = s.docs.map(Booking.fromFirestore).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Streams all users.
  Stream<List<AppUser>> getAllUsersStream() {
    return _db.collection('users').snapshots().map(
          (s) => s.docs.map(AppUser.fromFirestore).toList(),
        );
  }

  /// Toggle a turf's active status.
  Future<void> toggleTurfActive(String turfId, bool isActive) {
    return _db.collection('turfs').doc(turfId).update({
      'isActive': isActive,
    });
  }

  /// Change a user's role (player, owner, admin).
  Future<void> updateUserRole(String userId, String role) {
    return _db.collection('users').doc(userId).update({
      'role': role,
    });
  }
}
