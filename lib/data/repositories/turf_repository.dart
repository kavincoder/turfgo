import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/turf.dart';

class TurfRepository {
  final _db = FirebaseFirestore.instance;

  // Fetch all active turfs for a city — filtered client-side for isActive
  // to avoid composite index requirement in Firestore.
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
