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
}
