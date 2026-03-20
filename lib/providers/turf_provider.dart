import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/turf_repository.dart';
import '../data/repositories/slot_repository.dart';
import '../models/turf.dart';
import '../models/slot.dart';

final turfRepositoryProvider = Provider<TurfRepository>(
  (ref) => TurfRepository(),
);

final slotRepositoryProvider = Provider<SlotRepository>(
  (ref) => SlotRepository(),
);

// Real-time turf stream per cityId — updates immediately when Firestore changes.
final turfsProvider = StreamProvider.family<List<Turf>, String>(
  (ref, cityId) => ref.watch(turfRepositoryProvider).getTurfsStream(cityId),
);

// Cache single turf per turfId.
final turfDetailProvider = FutureProvider.family<Turf, String>(
  (ref, turfId) => ref.watch(turfRepositoryProvider).getTurf(turfId),
);

// Params for slot stream — Dart records auto-implement == and hashCode.
typedef SlotQueryParams = ({String turfId, String date});

// Real-time slot stream — refreshes automatically when Firestore data changes.
final slotsProvider = StreamProvider.family<List<Slot>, SlotQueryParams>(
  (ref, params) => ref
      .watch(slotRepositoryProvider)
      .getSlotsStream(params.turfId, params.date),
);
