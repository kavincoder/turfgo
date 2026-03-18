import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/booking.dart';

class BookingRepository {
  final _db = FirebaseFirestore.instance;

  Stream<List<Booking>> getBookingsStream(String userId) {
    return _db
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) {
          final list = s.docs.map(Booking.fromFirestore).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        })
        .handleError((Object e, StackTrace st) {
          debugPrint('[BookingRepository] getBookingsStream error: $e\n$st');
          // Re-throw so the StreamProvider surfaces an error state to the UI
          throw e;
        });
  }
}
