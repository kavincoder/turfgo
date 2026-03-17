import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/admin_repository.dart';
import '../models/app_user.dart';
import '../models/booking.dart';
import '../models/turf.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(),
);

final allTurfsStreamProvider = StreamProvider<List<Turf>>((ref) {
  return ref.watch(adminRepositoryProvider).getAllTurfsStream();
});

final allBookingsStreamProvider = StreamProvider<List<Booking>>((ref) {
  return ref.watch(adminRepositoryProvider).getAllBookingsStream();
});

final allUsersStreamProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(adminRepositoryProvider).getAllUsersStream();
});
