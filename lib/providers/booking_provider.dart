import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/booking_repository.dart';
import '../models/booking.dart';

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(),
);

final bookingsStreamProvider = StreamProvider<List<Booking>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(bookingRepositoryProvider).getBookingsStream(uid);
});
