import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../models/slot.dart';

class SlotRepository {
  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;

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

  /// Owner blocks a slot via Cloud Function (slots are CF-write-only).
  Future<void> ownerLockSlot(String turfId, String slotId) =>
      _setOwnerBlock(turfId, slotId, true);

  /// Owner unblocks a previously owner-blocked slot.
  Future<void> ownerUnlockSlot(String turfId, String slotId) =>
      _setOwnerBlock(turfId, slotId, false);

  Future<void> _setOwnerBlock(String turfId, String slotId, bool blocked) {
    return _functions.httpsCallable('ownerSetSlotBlock').call({
      'turfId': turfId,
      'slotId': slotId,
      'blocked': blocked,
    });
  }
}
