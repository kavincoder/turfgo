import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/booking_repository.dart';
import '../models/booking.dart';
import 'auth_provider.dart';

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(),
);

final bookingsStreamProvider = StreamProvider<List<Booking>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value([]);
  return ref.watch(bookingRepositoryProvider).getBookingsStream(uid);
});
