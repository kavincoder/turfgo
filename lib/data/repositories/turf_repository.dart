import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/turf.dart';

class TurfRepository {
  final _db = FirebaseFirestore.instance;

  // Real-time stream of active turfs for a city.
  // Filtered client-side for isActive to avoid a composite Firestore index.
  Stream<List<Turf>> getTurfsStream(String cityId) {
    return _db
        .collection('turfs')
        .where('cityId', isEqualTo: cityId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(Turf.fromFirestore)
            .where((t) => t.isActive)
            .toList());
  }

  // One-shot fetch (kept for admin/internal use).
  Future<List<Turf>> getTurfs(String cityId) async {
    final snapshot = await _db
        .collection('turfs')
        .where('cityId', isEqualTo: cityId)
        .get();
    return snapshot.docs
        .map(Turf.fromFirestore)
        .where((t) => t.isActive)
        .toList();
  }

  Future<Turf> getTurf(String turfId) async {
    final doc = await _db.collection('turfs').doc(turfId).get();
    if (!doc.exists) throw Exception('Turf not found: $turfId');
    return Turf.fromFirestore(doc);
  }
}
