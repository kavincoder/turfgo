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

  // Generates slot documents for a turf/date if they don't exist yet.
  // The stream in getSlotsStream auto-updates once the CF writes the docs.
  Future<void> generateSlots({
    required String turfId,
    required String date,
  }) async {
    final callable = _functions.httpsCallable('generateSlots');
    await callable.call({'turfId': turfId, 'date': date});
  }
}
