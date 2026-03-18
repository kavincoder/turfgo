import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/booking.dart';
import '../../models/turf.dart';

class OwnerRepository {
  final _db = FirebaseFirestore.instance;

  /// Fetches all turfs owned by this user.
  Future<List<Turf>> getOwnerTurfs(String ownerId) async {
    final snap = await _db
        .collection('turfs')
        .where('ownerId', isEqualTo: ownerId)
        .get();
    return snap.docs.map(Turf.fromFirestore).toList();
  }

  /// Streams all bookings for the given turf IDs.
  /// Firestore `whereIn` supports up to 30 values — fine for early stage.
  Stream<List<Booking>> getOwnerBookingsStream(List<String> turfIds) {
    if (turfIds.isEmpty) return Stream.value([]);
    return _db
        .collection('bookings')
        .where('turfId', whereIn: turfIds)
        .snapshots()
        .map((s) {
          final list = s.docs.map(Booking.fromFirestore).toList();
          list.sort((a, b) {
            // Sort by date + time ascending (soonest first)
            final dateCompare = a.slotDate.compareTo(b.slotDate);
            if (dateCompare != 0) return dateCompare;
            return a.slotStartTime.compareTo(b.slotStartTime);
          });
          return list;
        })
        .handleError((Object e, StackTrace st) {
          debugPrint('[OwnerRepository] getOwnerBookingsStream error: $e\n$st');
          throw e;
        });
  }
}
