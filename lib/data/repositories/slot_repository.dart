import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/slot.dart';

class SlotRepository {
  final _db = FirebaseFirestore.instance;

  // Real-time stream — UI updates instantly when a slot is booked or locked.
  Stream<List<Slot>> getSlotsStream(String turfId, String date) {
    return _db
        .collection('turfs')
        .doc(turfId)
        .collection('slots')
        .where('date', isEqualTo: date)
        .snapshots()
        .map((s) => s.docs.map(Slot.fromFirestore).toList());
  }

  /// Owner locks an available slot (blocks it from player bookings).
  /// Sets lockedUntil 10 years in the future, lockedBy: 'owner'.
  Future<void> ownerLockSlot(String turfId, String slotId) {
    final far = DateTime.now().add(const Duration(days: 3650));
    return _db
        .collection('turfs')
        .doc(turfId)
        .collection('slots')
        .doc(slotId)
        .update({
      'lockedUntil': Timestamp.fromDate(far),
      'lockedBy': 'owner',
    });
  }

  /// Owner unlocks a previously owner-blocked slot.
  Future<void> ownerUnlockSlot(String turfId, String slotId) {
    return _db
        .collection('turfs')
        .doc(turfId)
        .collection('slots')
        .doc(slotId)
        .update({
      'lockedUntil': null,
      'lockedBy': null,
    });
  }
}
