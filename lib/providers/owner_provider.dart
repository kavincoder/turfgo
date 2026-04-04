import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/owner_repository.dart';
import '../models/booking.dart';
import '../models/turf.dart';
import 'auth_provider.dart';

final ownerRepositoryProvider = Provider<OwnerRepository>(
  (ref) => OwnerRepository(),
);

/// All turfs owned by the current user.
final ownerTurfsProvider = FutureProvider<List<Turf>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Future.value([]);
  return ref.watch(ownerRepositoryProvider).getOwnerTurfs(uid);
});

/// Real-time stream of all bookings across the owner's turfs.
final ownerBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final turfsAsync = ref.watch(ownerTurfsProvider);
  return turfsAsync.when(
    data: (turfs) {
      final turfIds = turfs.map((t) => t.id).toList();
      return ref
          .watch(ownerRepositoryProvider)
          .getOwnerBookingsStream(turfIds);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});
